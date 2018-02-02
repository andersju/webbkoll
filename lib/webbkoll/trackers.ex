defmodule Webbkoll.Trackers do
  # Make sure trackers.ex is recompiled if services.json changes
  @external_resource Application.app_dir(:webbkoll, "priv/services.json")

  # We want to be able to match domains against Disconnect's open source list
  # of trackers (https://github.com/disconnectme/disconnect-tracking-protection),
  # however their services.json has the actual domains a few levels deep in the
  # structure. The following parses the JSON file and creates a map where each
  # unique host is a key. Additionally, by making this a module attribute, we
  # ensure that this is only done at compile time.

  # TODO: Clean up this mess
  @hosts (fn ->
            Application.app_dir(:webbkoll, "priv/services.json")
            |> File.read!()
            |> Poison.decode!()
            |> Map.get("categories")
            |> Enum.reduce(%{}, fn {category, sites}, hosts ->
              if String.starts_with?(category, "Legacy") do
                hosts
              else
                Enum.reduce(sites, hosts, fn site, hosts ->
                  Enum.reduce(site, hosts, fn {name, url}, hosts ->
                    url
                    |> Enum.filter(fn {x, _y} -> String.starts_with?(x, ["http", "www."]) end)
                    |> Enum.into(%{})
                    |> Map.values()
                    |> List.first()
                    |> Enum.reduce(hosts, fn host, hosts ->
                      Map.put_new(hosts, host, "#{category} (#{name})")
                    end)
                  end)
                end)
              end
            end)
          end).()

  def check(host) do
    case Map.fetch(@hosts, host) do
      {:ok, value} ->
        value

      :error ->
        if to_string(host) =~ ~r/^www\./ do
          Regex.replace(~r/^www\./, host, "") |> check
        else
          nil
        end
    end
  end
end
