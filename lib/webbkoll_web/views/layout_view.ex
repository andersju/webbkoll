defmodule WebbkollWeb.LayoutView do
  use WebbkollWeb, :view

  @webbkoll_version Application.compile_env(:webbkoll, :version)
  @webbkoll_locales Application.compile_env(:webbkoll, :locales)

  # Yes this is a little ugly
  def path_helper(conn, lang) do
    if conn.private[:phoenix_controller] == WebbkollWeb.SiteController do
      Routes.site_path(conn, conn.private[:phoenix_action], lang, conn.query_params)
    else
      Routes.page_path(conn, conn.private[:phoenix_action], lang, conn.query_params)
    end
  end

  def webbkoll_version(), do: @webbkoll_version
  def webbkoll_locales(), do: @webbkoll_locales
end
