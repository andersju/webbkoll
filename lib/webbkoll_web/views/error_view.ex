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

  # def render("404.html", _assigns) do
  #  "Page not found"
  # end
  #
  # def render("500.html", _assigns) do
  #  "Server internal error"
  # end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("error.html", assigns)
  end

  # def template_not_found(template, _assigns) do
  #  %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  # end
end
