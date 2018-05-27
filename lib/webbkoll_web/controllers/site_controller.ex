defmodule WebbkollWeb.SiteController do
  use WebbkollWeb, :controller
  alias WebbkollWeb.Site

  @backends Application.get_env(:webbkoll, :backends)
  @rate_limit_client Application.get_env(:webbkoll, :rate_limit_client)
  @rate_limit_host Application.get_env(:webbkoll, :rate_limit_host)
  @validate_urls Application.get_env(:webbkoll, :validate_urls)

  plug(:check_for_bots when action in [:check])
  plug(:scrub_params, "url" when action in [:check])
  plug(:get_proper_url when action in [:check])
  plug(:validate_url when action in [:check] and @validate_urls)
  plug(:check_if_site_exists when action in [:check])
  plug(:check_rate_ip when action in [:check])
  plug(:check_rate_url_host when action in [:check])

  def index(conn, _params) do
    render(
      conn,
      "index.html",
      locale: conn.assigns.locale,
      page_title: gettext("Analyze"),
      page_description:
        gettext(
          "This tool helps you check what data-protecting measures a site has taken to help you exercise control over your privacy."
        )
    )
  end

  def indexi18n(conn, params), do: index(conn, params)

  def about(conn, _params) do
    render(
      conn,
      "about.html",
      locale: conn.assigns.locale,
      page_title: gettext("About"),
      page_description:
        gettext(
          "The what and why of data protection and the principles of the EU general data protection regulation."
        )
    )
  end

  def tech(conn, _params) do
    render(
      conn,
      "tech.html",
      locale: conn.assigns.locale,
      page_title: gettext("Tech"),
      page_description:
        gettext("How our web privacy check tool works and how you can run your own instance.")
    )
  end

  def check(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    site = %Site{
      input_url: proper_url,
      try_count: 0,
      status: "queue",
      inserted_at: System.system_time(:microsecond)
    }

    id = UUID.uuid4()

    ConCache.put(:site_cache, id, site)

    {queue, settings} = Enum.random(@backends)

    Jumbo.Queue.enqueue(queue, Webbkoll.Worker, [
      id,
      proper_url,
      conn.params["refresh"],
      settings.url
    ])

    redirect(conn, to: site_path(conn, :status, conn.assigns.locale, id: id))
  end

  def status(conn, %{"id" => id}) do
    case UUID.info(id) do
      {:error, _} -> handle_status(nil, id, conn)
      {:ok, _} -> ConCache.get(:site_cache, id) |> handle_status(id, conn)
    end
  end

  defp handle_status(nil, _id, conn) do
    redirect(conn, to: site_path(conn, :indexi18n, conn.assigns.locale))
  end

  defp handle_status(site, id, conn) do
    case site.status do
      "queue" ->
        render(conn, "status.html", id: id, site: site, page_title: gettext("Status"))

      "processing" ->
        render(conn, "status.html", id: id, site: site, page_title: gettext("Status"))

      "failed" ->
        redirect(conn, to: site_path(conn, :results, conn.assigns.locale, url: site.input_url))

      "done" ->
        redirect(conn, to: site_path(conn, :results, conn.assigns.locale, url: site.input_url))
    end
  end

  def results(conn, %{"url" => url}) do
    url
    |> get_latest_from_cache()
    |> handle_results(conn, url)
  end

  defp handle_results(nil, conn, url) do
    redirect(conn, to: site_path(conn, :check, conn.assigns.locale, url: url))
  end

  defp handle_results({id, site}, conn, _url) do
    case site.status do
      "queue" ->
        redirect(conn, to: site_path(conn, :status, conn.assigns.locale, id: id, site: site))

      "processing" ->
        redirect(conn, to: site_path(conn, :status, conn.assigns.locale, id: id, site: site))

      "failed" ->
        render(conn, :failed, site: site, page_title: gettext("Processing failed"))

      "done" ->
        render(
          conn,
          :results,
          site: site,
          page_title: gettext("Results for %{url}", url: truncate(site.final_url, 50)),
          page_description: gettext("How this website is doing with regards to privacy.")
        )
    end
  end

  defp get_latest_from_cache(url) do
    input = :ets.match_object(ConCache.ets(:site_cache), {:_, %{input_url: url}})

    input
    |> Enum.filter(&is_tuple/1)
    |> Enum.sort(fn x, y ->
      elem(x, 1) |> Map.get(:inserted_at) > elem(y, 1) |> Map.get(:inserted_at)
    end)
    |> List.first()
  end

  # Plugs

  defp check_for_bots(conn, _params) do
    conn
    |> get_req_header("user-agent")
    |> check_user_agent(conn)
  end

  defp check_user_agent([user_agent], conn) do
    bot_pattern = ~r/bot|crawl|slurp|spider/i

    case Regex.match?(bot_pattern, user_agent) do
      true -> render_error(conn, gettext("Sorry, bots aren't allowed."))
      false -> conn
    end
  end

  defp check_user_agent([], conn), do: conn

  defp get_proper_url(url = %URI{}) do
    path = url.path || "/"

    case @validate_urls do
      true -> "http://#{url.host |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase()}#{path}"
      false -> "http://#{url.authority |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase()}#{path}"
    end
  end

  defp get_proper_url(conn, _params) do
    url =
      case String.starts_with?(conn.params["url"], ["http://", "https://"]) do
        true -> conn.params["url"] |> URI.parse() |> get_proper_url
        false -> "http://#{conn.params["url"]}" |> URI.parse() |> get_proper_url
      end

    assign(conn, :input_url, url)
  end

  defp validate_url(conn, _params) do
    conn.assigns.input_url
    |> URI.parse()
    |> Map.get(:host)
    |> PublicSuffix.matches_explicit_rule?()
    |> case do
      true ->
        conn

      false ->
        render_error(
          conn,
          gettext("Invalid domain: %{domain}", domain: conn.assigns.input_url)
        )
    end
  end

  defp check_if_site_exists(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    case conn.params["refresh"] do
      "on" -> conn
      _ -> check_site_in_cache(conn, proper_url)
    end
  end

  defp check_site_in_cache(conn, proper_url) do
    proper_url
    |> get_latest_from_cache()
    |> handle_check_site_in_cache(conn)
  end

  defp handle_check_site_in_cache({id, _site}, conn) do
    conn
    |> redirect(to: site_path(conn, :status, conn.assigns.locale, id: id))
    |> halt
  end

  defp handle_check_site_in_cache(_, conn), do: conn

  defp check_rate_ip(conn, _params) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
    |> ExRated.check_rate(@rate_limit_client["scale"], @rate_limit_client["limit"])
    |> case do
      {:ok, _} ->
        conn

      {:error, _} ->
        render_error(conn, gettext("You're requesting too frequently. Install locally?"))
    end
  end

  defp check_rate_url_host(conn, _params) do
    conn.assigns.input_url
    |> URI.parse()
    |> Map.get(:host)
    |> ExRated.check_rate(@rate_limit_host["scale"], @rate_limit_host["limit"])
    |> case do
      {:ok, _} ->
        conn

      {:error, _} ->
        render_error(conn, gettext("Trying same host too frequently. Try again in a minute."))
    end
  end

  defp render_error(conn, error_message) do
    conn
    |> put_status(400)
    |> render(:error, error_message: error_message, page_title: gettext("Error"))
    |> halt
  end
end
