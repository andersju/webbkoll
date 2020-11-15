defmodule WebbkollWeb.API.SiteController do
  use WebbkollWeb, :controller
  import WebbkollWeb.ControllerHelpers
  import WebbkollWeb.Plugs
  alias Webbkoll.Sites

  @validate_urls Application.get_env(:webbkoll, :validate_urls)

  plug(:scrub_params, "url" when action in [:create])
  plug(:get_proper_url when action in [:create])
  plug(:validate_domain when action in [:create] and @validate_urls)
  plug(:validate_url when action in [:create] and @validate_urls)

  def create(%Plug.Conn{assigns: %{input_url: proper_url}} = conn, _params) do
    site = enqueue_site(conn, proper_url)
    render(conn, "show.json", site: site)
  end

  def show(conn, %{"id" => id}) do
    case Sites.get_site(id) do
      nil -> render_error(conn, 400, "Invalid ID")
      site -> render(conn, "show.json", site: site)
    end
  end
end
