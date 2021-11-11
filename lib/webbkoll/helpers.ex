defmodule Webbkoll.Helpers do
  def language_from_code(code), do: Application.get_env(:webbkoll, :locales) |> Map.get(code)

  def get_proper_ip("[" <> rest), do: String.slice(rest, 0..-2)

  def get_proper_ip(ip), do: ip

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

  def is_third_party_domain?(url, registrable_domain) do
    host = URI.parse(url).host
    host !== nil && get_registerable_domain(host) !== registrable_domain
  end

  def get_registerable_domain(host) do
    case PublicSuffix.matches_explicit_rule?(host) do
      true ->
        # Workaround to handle the fact that some entities serve content directly
        # at the public suffix level, and we want to be able to check those too.
        # TODO: rename get_registerable_domain to something more appropriate.
        case PublicSuffix.registrable_domain(host) do
          nil -> host
          reg_domain -> reg_domain
        end
      false -> host
    end
  end
end
