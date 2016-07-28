defmodule Webbkoll.SiteView do
  use Webbkoll.Web, :view

  def format_timestamp(time) do
    time
    |> DateTime.from_unix!
    |> DateTime.to_string
  end
end
