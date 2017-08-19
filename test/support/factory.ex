defmodule Webbkoll.Factory do
  use ExMachina.Ecto, repo: Webbkoll.Repo

  def site_factory do
    %WebbkollWeb.Site{
      input_url: "example.com",
      final_url: "https://example.com/",
      status: "done",
    }
  end
end