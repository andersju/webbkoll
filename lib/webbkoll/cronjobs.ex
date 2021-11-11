defmodule Webbkoll.CronJobs do
  require Logger
  alias Webbkoll.Sites

  def find_and_remove_stuck_records do
    Logger.info("Checking for stuck records")
    sites_processing = Sites.get_sites_by(%{status: "processing"})
    max_attempts = Application.get_env(:webbkoll, :max_attempts)

    Enum.each(sites_processing, fn {id, site} ->
      if System.system_time(:microsecond) - site.updated_at > 40_000_000 &&
           site.try_count >= max_attempts do
        Sites.update_site(id, %{
          status: "failed",
          status_message: "Server error on our side."
        })
      end
    end)
  end
end
