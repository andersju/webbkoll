defmodule Webbkoll.CronJobs do
  def remove_stuck_records do
    IO.puts "Checking for stuck records"
    sites_processing = :ets.match_object(ConCache.ets(:site_cache), {:_, %{status: "processing"}})

    Enum.each(sites_processing, fn({id, site}) ->
      if (System.system_time(:microsecond) - site.updated_at) > 40_000_000 && site.try_count == 2 do
        Webbkoll.Worker.update_site(id, %{status: "failed", status_message: "Server error on our side."})
      end
    end)
  end
end
