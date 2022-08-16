defmodule WebbkollWeb.Plugs do
  import Plug.Conn
  import WebbkollWeb.Gettext

  alias WebbkollWeb.ControllerHelpers
  alias Webbkoll.Sites

  @rate_limit_client Application.get_env(:webbkoll, :rate_limit_client)
  @rate_limit_host Application.get_env(:webbkoll, :rate_limit_host)
  @validate_urls Application.get_env(:webbkoll, :validate_urls)
  @check_host_only Application.get_env(:webbkoll, :check_host_only)

  def validate_domain(conn, _params) do
    conn.assigns.input_url
    |> URI.parse()
    |> Map.get(:host)
    |> PublicSuffix.matches_explicit_rule?()
    |> case do
      true ->
        conn

      false ->
        ControllerHelpers.render_error(
          conn,
          400,
          gettext("Invalid domain: %{domain}", domain: conn.assigns.input_url)
        )
    end
  end

  def validate_url(conn, _params) do
    url = URI.parse(conn.assigns.input_url)

    # For validation purposes we convert back from ASCII to Unicode.
    # TODO: Make all this less messy
    URI.to_string(%URI{
      host: url.host |> :idna.from_ascii() |> List.to_string() |> String.downcase(),
      path: url.path,
      query: url.query,
      scheme: "http"
    })
    |> ValidUrl.validate()
    |> case do
      true ->
        conn

      false ->
        ControllerHelpers.render_error(
          conn,
          400,
          gettext("Invalid URL: %{url}", url: conn.assigns.input_url)
        )
    end
  end

  def check_for_bots(conn, _params) do
    conn
    |> get_req_header("user-agent")
    |> check_user_agent(conn)
  end

  def check_user_agent([user_agent], conn) do
    bot_pattern = ~r/bot|crawl|slurp|spider/i

    case Regex.match?(bot_pattern, user_agent) do
      true -> ControllerHelpers.render_error(conn, 400, gettext("Sorry, bots aren't allowed."))
      false -> conn
    end
  end

  def check_user_agent([], conn), do: conn

  def get_proper_url(url = %URI{}) do
    # :idna.utf8_to_ascii() exits on invalid input, so here's a fugly workaround.
    try do
      case @validate_urls do
        true ->
          URI.to_string(%URI{
            host: url.host |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase(),
            path: if(@check_host_only, do: nil, else: url.path),
            query: if(@check_host_only, do: nil, else: url.query),
            scheme: "http"
          })

        false ->
          URI.to_string(%URI{
            host: url.host |> :idna.utf8_to_ascii() |> List.to_string() |> String.downcase(),
            path: url.path,
            query: url.query,
            scheme: "http",
            port: url.port
          })
      end
    catch
      kind, _ when kind in [:error, :exit, :throw] -> nil
    end
  end

  def get_proper_url(conn, _params) do
    url =
      case String.starts_with?(conn.params["url"], ["http://", "https://"]) do
        true -> conn.params["url"] |> URI.parse() |> get_proper_url()
        false -> "http://#{conn.params["url"]}" |> URI.parse() |> get_proper_url()
      end

    case url do
      nil ->
        ControllerHelpers.render_error(
          conn,
          400,
          gettext("Invalid URL: %{url}", url: conn.params["url"])
        )

      url ->
        assign(conn, :input_url, url)
    end
  end

  def check_rate_ip(conn, _params) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
    |> ExRated.check_rate(@rate_limit_client["scale"], @rate_limit_client["limit"])
    |> case do
      {:ok, _} ->
        conn

      {:error, _} ->
        ControllerHelpers.render_error(
          conn,
          429,
          gettext("You're requesting too frequently. Install locally?")
        )
    end
  end

  def check_rate_url_host(conn, _params) do
    conn.assigns.input_url
    |> URI.parse()
    |> Map.get(:host)
    |> ExRated.check_rate(@rate_limit_host["scale"], @rate_limit_host["limit"])
    |> case do
      {:ok, _} ->
        conn

      {:error, _} ->
        ControllerHelpers.render_error(
          conn,
          429,
          gettext("Trying same host too frequently. Try again in a minute.")
        )
    end
  end

  def validate_id(%Plug.Conn{query_params: %{"id" => id}} = conn, _params) do
    case Sites.is_valid_id?(id) do
      {:ok, _} ->
        conn

      {:error, _} ->
        ControllerHelpers.render_error(conn, 400, gettext("Invalid id."))
    end
  end
end
