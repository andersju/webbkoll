# Heavily inspired by https://github.com/mozilla/http-observatory by April King
defmodule Webbkoll.HeaderAnalysis do
  def hsts(nil), do: %{set: false}
  def hsts(header, host, reg_domain) do
    if host == reg_domain do
      %{host: hsts(header)}
    else
      case Webbkoll.Helpers.find_header("https://#{reg_domain}", "strict-transport-security") do
        {:ok, reg_domain_header} -> %{host: hsts(header), base: hsts(reg_domain_header)}
        {:error, _} -> %{host: hsts(header)}
      end
    end
  end
  def hsts(header) do
    data = header |> String.slice(0, 1024)
    directives = data |> String.downcase |> String.split(";") |> Enum.map(&String.trim/1)

    %{
      data: data,
      max_age: nil,
      includesubdomains: false,
      preload: false,
      pass: false,
      set: true
    }
    |> hsts_check_max_age(directives)
    |> hsts_check_subdomains(directives)
    |> hsts_check_preload(directives)
    |> hsts_get_result()
  end

  defp hsts_check_max_age(map, directives) do
    case Enum.find(directives, fn x -> String.starts_with?(x, "max-age") end) do
      nil -> map
      directive ->
        case Integer.parse(String.slice(directive, 8, 128)) do
          {value, ""} -> %{map | max_age: value}
          _ -> map
        end
    end
  end

  defp hsts_check_subdomains(map, directives) do
    case "includesubdomains" in directives do
      true -> %{map | includesubdomains: true}
      false -> map
    end
  end

  defp hsts_check_preload(map, directives) do
    case "preload" in directives do
      true -> %{map | preload: true}
      false -> map
    end
  end

  defp hsts_get_result(map) do
    if is_integer(map.max_age) && map.max_age >= 15552000 do # 180 days
      %{map | pass: true}
    else
      map
    end
  end
end