defmodule Webbkoll.Helpers do
  @countries (fn ->
                for lang <- Map.keys(Application.get_env(:webbkoll, :locales)), into: %{} do
                  {lang,
                   Application.app_dir(:webbkoll, "priv/#{lang}.json")
                   |> File.read!()
                   |> Jason.decode!()}
                end
              end).()

  def country_from_iso(locale, country_code) do
    case Map.fetch(@countries[locale]["countries"], country_code) do
      :error -> nil
      {:ok, country} -> country
    end
  end

  def language_from_code(code), do: Application.get_env(:webbkoll, :locales) |> Map.get(code)

  def get_geolocation_by_ip(nil), do: nil

  def get_geolocation_by_ip(ip) do
    ip
    |> Geolix.lookup(as: :raw, where: :country, locale: :en)
    |> get_in([:country, :iso_code])
  end

  def get_unique_hosts(data, field_name) do
    data
    |> Enum.map(& &1[field_name])
    |> Enum.uniq()
  end

  def truncate(string, maximum) do
    case String.length(string) > maximum do
      true -> "#{String.slice(string, 0, maximum)}..."
      false -> string
    end
  end

  def idna_from_punycode(host) do
    host
    |> String.to_charlist()
    |> :idna.from_ascii()
    |> List.to_string()
  end

  def get_headers(url) when is_binary(url) do
    url
    |> HTTPoison.head()
    |> handle_get_headers()
  end

  def handle_get_headers({:ok, response}) do
    {:ok, Enum.map(response.headers, fn {k, v} -> {String.downcase(k), v} end)}
  end

  def handle_get_headers({:error, reason}) do
    {:error, reason}
  end

  def find_header(url, header) do
    url
    |> get_headers()
    |> handle_find_header(header)
  end

  defp handle_find_header({:error, reason}, _), do: {:error, reason}

  defp handle_find_header({:ok, headers}, header) do
    headers
    |> Enum.find(fn {k, _} -> k == header end)
    |> case do
      nil -> {:ok, nil}
      {_, v} -> {:ok, v}
    end
  end

  def get_registerable_domain(host) do
    case PublicSuffix.matches_explicit_rule?(host) do
      true -> PublicSuffix.registrable_domain(host)
      false -> host
    end
  end
end
