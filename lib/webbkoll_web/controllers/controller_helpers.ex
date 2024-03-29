defmodule WebbkollWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  import WebbkollWeb.Gettext

  alias Webbkoll.Sites

  @backends Application.compile_env(:webbkoll, :backends)

  def enqueue_site(conn, url) do
    {queue, settings} = Enum.random(@backends)

    {:ok, site} = Sites.add_site(url)

    {
      :perform,
      [
        site.id,
        url,
        conn.params["refresh"],
        settings.url
      ]
    }
    |> Honeydew.async(queue)

    site
  end

  def render_error(conn, status, error_message) do
    conn
    |> put_status(status)
    |> put_view(WebbkollWeb.ErrorView)
    |> render(:"#{status}", error_message: error_message, page_title: gettext("Error"))
    |> halt()
  end
end
