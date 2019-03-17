defmodule WebbkollWeb.SiteController do
  use WebbkollWeb, :controller
  alias Webbkoll.Sites

  @backends Application.get_env(:webbkoll, :backends)
  @rate_limit_client Application.get_env(:webbkoll, :rate_limit_client)
  @rate_limit_host Application.get_env(:webbkoll, :rate_limit_host)
  @validate_urls Application.get_env(:webbkoll, :validate_urls)

  plug(:check_for_bots when action in [:check])
  plug(:scrub_params, "url" when action in [:check])
  plug(:get_proper_url when action in [:check])
  plug(:validate_domain when action in [:check] and @validate_urls)
  plug(:validate_url when action in [:check] and @validate_urls)
  plug(:check_if_site_exists when action in [:check])
  plug(:check_rate_ip when action in [:check])
  plug(:check_rate_url_host when action in [:check])
  plug(:validate_id when action in [:status])

  def check(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    {:ok, id} = Sites.add_site(proper_url)

    {queue, settings} = Enum.random(@backends)

    Jumbo.Queue.enqueue(queue, Webbkoll.Worker, [
      id,
      proper_url,
      conn.params["refresh"],
      settings.url
    ])

    redirect(conn, to: Routes.site_path(conn, :status, conn.assigns.locale, id: id))
  end

  def status(conn, %{"id" => id}) do
    id
    |> Sites.get_site()
    |> handle_status(id, conn)
  end

  defp handle_status(%Sites.Site{status: "done"} = site, _id, conn) do
    redirect(conn,
      to: Routes.site_path(conn, :results, conn.assigns.locale, url: site.input_url)
    )
  end

  defp handle_status(nil, id, conn) do
    render_error(conn, gettext("Invalid ID."))
  end

  defp handle_status(site, id, conn) do
    case site.status do
      x when x in ["queue", "processing"] ->
        render(conn, "status.html", id: id, site: site, page_title: gettext("Status"))

      x when x in ["failed", "done"] ->
        redirect(conn,
          to: Routes.site_path(conn, :results, conn.assigns.locale, url: site.input_url)
        )
    end
  end

  def results(conn, %{"url" => url}) do
    url
    |> Sites.get_latest_from_cache()
    |> handle_results(conn, url)
  end

  defp handle_results(nil, conn, url) do
    redirect(conn, to: Routes.site_path(conn, :check, conn.assigns.locale, url: url))
  end

  defp handle_results({id, site}, conn, _url) do
    case site.status do
      x when x in ["queue", "processing"] ->
        redirect(conn,
          to: Routes.site_path(conn, :status, conn.assigns.locale, id: id, site: site)
        )

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
    case @validate_urls do
      true ->
        URI.to_string(%URI{
          host: url.host |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase(),
          path: url.path,
          query: url.query,
          scheme: "http"
        })

      false ->
        URI.to_string(%URI{
          host: url.authority |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase(),
          path: url.path,
          query: url.query,
          scheme: "http"
        })
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

  defp validate_domain(conn, _params) do
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

  defp validate_url(conn, _params) do
    case ValidUrl.validate(conn.assigns.input_url) do
      true ->
        conn

      false ->
        render_error(
          conn,
          gettext("Invalid URL: %{url}", url: conn.assigns.input_url)
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
    |> Sites.get_latest_from_cache()
    |> handle_check_site_in_cache(conn)
  end

  defp handle_check_site_in_cache({id, _site}, conn) do
    conn
    |> redirect(to: Routes.site_path(conn, :status, conn.assigns.locale, id: id))
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

  defp validate_id(%Plug.Conn{query_params: %{"id" => id}} = conn, _params) do
    case Sites.is_valid_id?(id) do
      {:ok, _} ->
        conn

      {:error, _} ->
        render_error(conn, gettext("Invalid id."))
    end
  end

  defp render_error(conn, error_message) do
    conn
    |> put_status(400)
    |> render(:error, error_message: error_message, page_title: gettext("Error"))
    |> halt
  end
end
