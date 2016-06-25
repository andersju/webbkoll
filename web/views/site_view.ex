defmodule Webbkoll.SiteView do
  use Webbkoll.Web, :view

  def format_timestamp(time) do
    time
    |> Timex.DateTime.from_seconds
    |> Timex.format!("%Y-%m-%d %H:%M:%S", :strftime)
  end
end
