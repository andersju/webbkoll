defmodule WebbkollWeb.API.SiteView do
  use WebbkollWeb, :view

  def render("show.json", assigns) do
    assigns.site
  end
end
