defmodule Webbkoll.Trackers do
  # Make sure trackers.ex is recompiled if services.json changes
  @external_resource Application.app_dir(:webbkoll, "priv/services.json")

  # We want to be able to match domains against Disconnect's open source list
  # of trackers (https://github.com/disconnectme/disconnect-tracking-protection),
  # however their services.json has the actual domains a few levels deep in the
  # structure. The following parses the JSON file and creates a map where each
  # unique host is a key. Additionally, by making this a module attribute, we
  # ensure that this is only done at compile time.
  @hosts (fn ->
            categories =
              Application.app_dir(:webbkoll, "priv/services.json")
              |> File.read!()
              |> Poison.decode!()
              |> Map.get("categories")

            for {category, value} <- categories, organization <- value do
              {name, org_values} = Enum.at(organization, 0)

              for {url, hosts} <- org_values, String.starts_with?(url, ["http", "www."]) and is_list(hosts) do
                for host <- hosts do
                  {host, "#{category} (#{name})"}
                end
              end
            end
            |> List.flatten()
            |> Enum.reject(&is_nil/1)
            |> Enum.into(%{})
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
