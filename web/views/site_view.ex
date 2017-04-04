defmodule Webbkoll.SiteView do
  use Webbkoll.Web, :view

  def format_timestamp(time) do
    time
    |> DateTime.from_unix!
    |> DateTime.to_string
  end

  def format_naivedatetime(naivedatetime) do
    Timex.format!(naivedatetime, "%Y-%m-%d %H:%M:%S", :strftime)
  end
end
