defmodule Webbkoll.CronJobs do
  alias WebbkollWeb.Site
  alias Webbkoll.Repo
  import Ecto.Query

  def remove_old_records do
    Site
    |> where([s], s.inserted_at < datetime_add(^Ecto.DateTime.utc, -1, "week"))
    |> Repo.delete_all
  end

  def remove_stuck_records do
    Site
    |> where([s], s.inserted_at < datetime_add(^Ecto.DateTime.utc, -30, "minute") and s.status == "queue")
    |> Repo.delete_all
  end
end
