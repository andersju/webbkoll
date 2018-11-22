# This is basically an Elixir version of April King's Python code for Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically httpobs/scanner/analyzer/content.py.
# License: Mozilla Public License Version 2.0.
defmodule Webbkoll.ContentAnalysis do
  import Webbkoll.Helpers

  @goodness [
    "sri-implemented-and-all-scripts-loaded-securely",
    "sri-implemented-and-external-scripts-loaded-securely",
    "sri-implemented-but-external-scripts-not-loaded-securely",
    "sri-not-implemented-but-external-scripts-loaded-securely",
    "sri-not-implemented-and-external-scripts-not-loaded-securely"
  ]
  @passing [
    "sri-implemented-and-all-scripts-loaded-securely",
    "sri-implemented-and-external-scripts-loaded-securely",
    "sri-not-implemented-but-all-scripts-loaded-from-secure-origin",
    "sri-not-implemented-but-no-scripts-loaded"
  ]

  def check_sri(content, reg_domain, site_scheme) do
    scripts = check_sri_content(content, reg_domain, site_scheme)
    output = check_scripts(scripts)
    scripts_on_foreign_origin = Enum.find(scripts, &(&1.secureorigin == false)) != nil

    output =
      cond do
        Enum.empty?(scripts) ->
          %{output | result: "sri-not-implemented-but-no-scripts-loaded"}

        !Enum.empty?(scripts) && !scripts_on_foreign_origin && !output.result ->
          %{output | result: "sri-not-implemented-but-all-scripts-loaded-from-secure-origin"}

        !Enum.empty?(scripts) && scripts_on_foreign_origin && !output.result ->
          %{output | result: "sri-implemented-and-external-scripts-loaded-securely"}

        true ->
          output
      end

    output =
      case output.result in @passing do
        true -> %{output | pass: true}
        false -> output
      end

    %{output | data: scripts}
  end

  defp check_scripts(scripts) do
    output = %{data: %{}, result: nil, pass: false}

    Enum.reduce(scripts, output, fn x, acc ->
      old_result = Map.get(acc, :result)

      if not x.secureorigin do
        cond do
          x.integrity && !x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-implemented-but-external-scripts-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-but-external-scripts-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && !x.securescheme && x.samesld ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-and-external-scripts-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && !x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-and-external-scripts-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          true ->
            acc
        end
      else
        cond do
          x.integrity && x.securescheme && !Map.has_key?(acc, :result) ->
            acc

          x.integrity && x.securescheme && !acc.result ->
            %{acc | result: "sri-implemented-and-all-scripts-loaded-securely"}

          true ->
            acc
        end
      end
    end)
  end

  defp check_sri_content(content, reg_domain, site_scheme) do
    content
    |> Floki.find("script[src]")
    |> Enum.reduce([], fn x, acc ->
      src = Floki.attribute(x, "src") |> List.first() || ""
      integrity = Floki.attribute(x, "integrity") |> List.first() || nil
      crossorigin = Floki.attribute(x, "crossorigin") |> List.first() || nil
      parsed_url = URI.parse(src)
      samesld = get_registerable_domain(parsed_url.host) == reg_domain

      {relativeorigin, relativeprotocol} =
        cond do
          !parsed_url.scheme && !parsed_url.host -> {true, false}
          !parsed_url.scheme -> {false, true}
          true -> {false, false}
        end

      secureorigin = relativeorigin or (samesld and not relativeprotocol)
      securescheme = parsed_url.scheme == "https" or (relativeorigin and site_scheme == "https")

      [
        %{
          src: src,
          crossorigin: crossorigin,
          integrity: integrity,
          secureorigin: secureorigin,
          securescheme: securescheme,
          samesld: samesld
        }
        | acc
      ]
    end)
  end

  defp sri_only_if_worse(new, old, goodness) do
    cond do
      !old -> new
      Enum.find_index(goodness, &(&1 == new)) > Enum.find_index(goodness, &(&1 == old)) -> new
      true -> old
    end
  end
end
