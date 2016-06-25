defmodule Webbkoll.Factory do
  use ExMachina.Ecto, repo: Webbkoll.Repo

  def factory(:site) do
    %Webbkoll.Site{
      input_url: "example.com",
      final_url: "https://example.com/",
      status: "done",
    }
  end
end