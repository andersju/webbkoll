# This is basically an Elixir version of April King's Python code for Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically httpobs/scanner/analyzer/content.py.
#
# License: Mozilla Public License Version 2.0.
defmodule Webbkoll.ContentAnalysis do
  import Webbkoll.Helpers

  @goodness [
    "sri-implemented-and-all-resources-loaded-securely",
    "sri-implemented-and-external-resources-loaded-securely",
    "sri-implemented-but-external-resources-not-loaded-securely",
    "sri-not-implemented-but-external-resources-loaded-securely",
    "sri-not-implemented-and-external-resources-not-loaded-securely"
  ]
  @passing [
    "sri-implemented-and-all-resources-loaded-securely",
    "sri-implemented-and-external-resources-loaded-securely",
    "sri-not-implemented-but-all-resources-loaded-from-secure-origin",
    "sri-not-implemented-but-no-resources-loaded"
  ]

  def sri(content, reg_domain, site_scheme) do
    resources = check_sri_content(content, reg_domain, site_scheme)
    output = check_resources(resources)
    resources_on_foreign_origin = Enum.find(resources, &(&1.secureorigin == false)) != nil

    output =
      cond do
        Enum.empty?(resources) ->
          %{output | result: "sri-not-implemented-but-no-resources-loaded"}

        !Enum.empty?(resources) && !resources_on_foreign_origin && !output.result ->
          %{output | result: "sri-not-implemented-but-all-resources-loaded-from-secure-origin"}

        !Enum.empty?(resources) && resources_on_foreign_origin && !output.result ->
          %{output | result: "sri-implemented-and-external-resources-loaded-securely"}

        true ->
          output
      end

    output =
      case output.result in @passing do
        true -> %{output | pass: true}
        false -> output
      end

    %{output | data: resources}
  end

  defp check_resources(resources) do
    output = %{data: %{}, result: nil, pass: false}

    Enum.reduce(resources, output, fn x, acc ->
      old_result = Map.get(acc, :result)

      if x.secureorigin do
        cond do
          x.integrity && x.securescheme && !Map.has_key?(acc, :result) ->
            acc

          x.integrity && x.securescheme && !acc.result ->
            %{acc | result: "sri-implemented-and-all-resources-loaded-securely"}

          true ->
            acc
        end
      else
        cond do
          x.integrity && !x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-implemented-but-external-resources-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-but-external-resources-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && !x.securescheme && x.samesld ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-and-external-resources-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          !x.integrity && !x.securescheme ->
            Map.put(
              acc,
              :result,
              sri_only_if_worse(
                "sri-not-implemented-and-external-resources-not-loaded-securely",
                old_result,
                @goodness
              )
            )

          true ->
            acc
        end
      end
    end)
  end

  defp check_sri_content(content, reg_domain, site_scheme) do
    content
    |> Floki.find("script[src], link[href][rel=\"stylesheet\"]")
    |> Enum.reduce([], fn x, acc ->
      src =
        case elem(x, 0) do
          "script" -> List.first(Floki.attribute(x, "src")) || ""
          "link" -> List.first(Floki.attribute(x, "href")) || ""
        end

      integrity = List.first(Floki.attribute(x, "integrity")) || nil
      crossorigin = List.first(Floki.attribute(x, "crossorigin")) || nil
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
          samesld: samesld,
          type: elem(x, 0)
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
