defmodule WebbkollWeb.LayoutView do
  use WebbkollWeb, :view

  # Yes this is a little ugly
  def path_helper(conn, lang) do
    if conn.private[:phoenix_controller] == WebbkollWeb.SiteController do
      Routes.site_path(conn, conn.private[:phoenix_action], lang, conn.query_params)
    else
      Routes.page_path(conn, conn.private[:phoenix_action], lang, conn.query_params)
    end
  end
end
