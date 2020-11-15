defmodule WebbkollWeb.API.ErrorView do
  use WebbkollWeb, :view

  def render("error.json", assigns) do
    %{errors: %{detail: assigns.error_message}}
  end

  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
