defmodule WebbkollWeb.SiteController do
  use WebbkollWeb, :controller
  import WebbkollWeb.ControllerHelpers
  import WebbkollWeb.Plugs
  alias Webbkoll.Sites
  alias Phoenix.Controller

 @validate_urls Application.get_env(:webbkoll, :validate_urls)

  plug(:check_for_bots when action in [:create])
  plug(:scrub_params, "url" when action in [:create])
  plug(:get_proper_url when action in [:create])
  plug(:validate_domain when action in [:create] and @validate_urls)
  plug(:validate_url when action in [:create] and @validate_urls)
  plug(:check_if_site_exists when action in [:create])
  plug(:check_rate_ip when action in [:create])
  plug(:check_rate_url_host when action in [:create])

  plug(:scrub_params, "id" when action in [:status])
  plug(:validate_id when action in [:status])

  plug(:scrub_params, "url" when action in [:results])

  def create(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    %{id: id} = enqueue_site(conn, proper_url)

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

  defp handle_status(nil, _id, conn) do
    render_error(conn, 404, gettext("ID not found"))
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
    redirect(conn, to: Routes.site_path(conn, :create, conn.assigns.locale, url: url))
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
          page_title: gettext("Results for %{url}", url: truncate(site.data.final_url, 50)),
          page_description: gettext("How this website is doing with regards to privacy.")
        )
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

  defp handle_check_site_in_cache({id, _site}, conn) do
    conn
    |> Controller.redirect(to: Routes.site_path(conn, :status, conn.assigns.locale, id: id))
    |> halt
  end

  defp handle_check_site_in_cache(_, conn), do: conn
end
