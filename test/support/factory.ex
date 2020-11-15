defmodule Webbkoll.Factory do
  use ExMachina

  def site_factory do
    %Webbkoll.Sites.Site{
      input_url: "example.com",
      status: "done",
      inserted_at: System.system_time(:microsecond),
      updated_at: System.system_time(:microsecond)
    }
  end
end
