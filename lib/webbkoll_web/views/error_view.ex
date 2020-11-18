defmodule WebbkollWeb.ErrorView do
  use WebbkollWeb, :view

  def render(<<status::binary-3>> <> ".json", assigns) do
    %{
      errors: %{
        detail: assigns.error_message
      },
      status: status
    }
  end

  def template_not_found(_template, %{error_message: error_message}) do
    render("error.html", error_message: error_message)
  end

  def template_not_found(template, _assigns) do
    render("error.html", error_message: Phoenix.Controller.status_message_from_template(template))
  end
end
