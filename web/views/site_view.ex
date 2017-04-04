defmodule Webbkoll.SiteView do
  use Webbkoll.Web, :view

  def format_timestamp(time) do
    time
    |> DateTime.from_unix!
    |> DateTime.to_string
  end

  def format_naivedatetime(naivedatetime) do
    naivedatetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Timex.format!("%Y-%m-%d %H:%M:%S %Z", :strftime)
  end
end
