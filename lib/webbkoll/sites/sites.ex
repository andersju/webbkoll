defmodule Webbkoll.Sites do
  alias Webbkoll.Sites.Site

  def add_site(url) do
    id = UUID.uuid4()

    site = %Site{
      id: id,
      input_url: url,
      try_count: 0,
      status: "queue",
      inserted_at: System.system_time(:microsecond)
    }

    ConCache.put(:site_cache, id, site)

    {:ok, site}
  end

  def update_site(id, params) do
    ConCache.update(:site_cache, id, fn old ->
      {
        :ok,
        old |> Map.merge(params) |> Map.merge(%{updated_at: System.system_time(:microsecond)})
      }
    end)
  end

  def increment_site_tries(id) do
    ConCache.update(:site_cache, id, fn old ->
      {:ok, Map.update(old, :try_count, 0, &(&1 + 1))}
    end)
  end

  def get_site(id) do
    ConCache.get(:site_cache, id)
  end

  def get_latest_from_cache(url) do
    input = get_sites_by(%{input_url: url})

    input
    |> Enum.filter(&is_tuple/1)
    |> Enum.sort(fn x, y ->
      elem(x, 1)
      |> Map.get(:inserted_at) >
        elem(y, 1)
        |> Map.get(:inserted_at)
    end)
    |> List.first()
  end

  def get_sites_by(params) do
    :ets.match_object(ConCache.ets(:site_cache), {:_, params})
  end

  def is_valid_id?(id) do
    UUID.info(id)
  end
end
