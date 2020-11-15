defmodule WebbkollWeb.API.SiteController do
  use WebbkollWeb, :controller
  import WebbkollWeb.ControllerHelpers
  import WebbkollWeb.Plugs
  alias Webbkoll.Sites

  @validate_urls Application.get_env(:webbkoll, :validate_urls)

  plug(:check_for_bots when action in [:create])
  plug(:scrub_params, "url" when action in [:create])
  plug(:get_proper_url when action in [:create])
  plug(:validate_domain when action in [:create] and @validate_urls)
  plug(:validate_url when action in [:create] and @validate_urls)
  plug(:check_if_site_exists when action in [:create])
  plug(:check_rate_ip when action in [:create])
  plug(:check_rate_url_host when action in [:create])

  def create(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    site = enqueue_site(conn, proper_url)
    render(conn, "show.json", site: site)
  end

  def show(conn, %{"id" => id}) do
    case Sites.get_site(id) do
      nil -> render_error(conn, 404, "ID not found")
      site -> render(conn, "show.json", site: site)
    end
  end

  def show(conn, %{"url" => url}) do
    url
    |> Sites.get_latest_from_cache()
    |> case do
      nil -> render_error(conn, 404, "URL not found among scanned sites")
      {_id, site} -> render(conn, "show.json", site: site)
    end
  end

  # Plugs

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

  defp handle_check_site_in_cache({_id, site}, conn) do
    conn
    |> render("show.json", site: site)
    |> halt()
  end

  defp handle_check_site_in_cache(_, conn), do: conn
end
