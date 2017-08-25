defmodule WebbkollWeb.SiteView do
  use WebbkollWeb, :view

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

  def get_referrer_string(status) do
    case status do
      "success" -> gettext("Referrers not leaked")
      "warning" -> gettext("Referrers partially leaked")
      "alert"   -> gettext("Referrers leaked")
      _ -> gettext("Referrers are (probably) leaked")
    end
  end
end
