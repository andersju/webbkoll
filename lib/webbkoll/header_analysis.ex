# This is basically an Elixir version of April King's Python code for Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically httpobs/scanner/analyzer/headers.py.
#
# License: Mozilla Public License Version 2.0.
#
# Sorry about the mess.

defmodule Webbkoll.HeaderAnalysis do
  import Webbkoll.Helpers

  @dangerously_broad [
    "ftp:",
    "http:",
    "https:",
    "*",
    "http://*",
    "http://*.*",
    "https://*",
    "https://*.*"
  ]
  @unsafe_inline ["'unsafe-inline'", "data:"]
  @passive_directives ["img-src", "media-src"]
  @nonces_hashes ["'sha256-", "'sha384-", "'sha512-", "'nonce-"]

  def parse_csp(nil), do: nil

  def parse_csp(string) do
    string
    |> String.replace("\n", ";")
    |> String.trim()
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.length(&1) < 6))
    |> Enum.reduce(%{}, fn x, acc ->
      # https://github.com/w3c/webappsec-csp/issues/236
      # ^- directive names still case-sensitive as of Chrome 70, so
      # don't make them lower-case, even though https://w3c.github.io/webappsec-csp/#parse-serialized-policy
      # specifies that directive names should be case-insensitive.
      # i.e.: non-lower-case directive name => fail (for the moment)
      [k | v] = String.split(x)
      # Directive values *should* be downcased, however.
      v = Enum.map(v, &String.downcase/1)
      # "An empty source list ... is equivalent to a source list containing 'none'"
      # https://w3c.github.io/webappsec-csp/#match-url-to-source-list
      v = if v == [], do: ["'none'"], else: v
      # TODO/NOTE: Unlike in the Python code this is based on, repeated directives
      # are currently silently ignored (only the first one is used).
      Map.put_new(acc, k, v)
    end)
    |> case do
      map when map == %{} -> nil
      map -> map
    end
  end

  def csp(scheme, http, meta, expectation \\ "csp-implemented-with-no-unsafe") do
    output = %{
      http: false,
      meta: false,
      pass: false,
      data: %{},
      policy: nil,
      expectation: expectation
    }

    case is_nil(http) and is_nil(meta) do
      true -> Map.put_new(output, :result, "csp-not-implemented")
      false -> handle_csp(scheme, output, http, meta)
    end
  end

  defp handle_csp(scheme, output, http, meta) do
    csp_http = parse_csp(http)
    csp_meta = parse_csp(meta)

    # If CSP has been set in both HTTP header and http-equiv meta element,
    # merge them.
    csp =
      case is_map(csp_http) and is_map(csp_meta) do
        true -> Map.merge(csp_http, csp_meta, fn _k, v1, v2 -> v1 ++ v2 end)
        _ -> csp_http || csp_meta
      end

    output = if csp_http, do: %{output | http: true}, else: output
    output = if csp_meta, do: %{output | meta: true}, else: output

    case is_nil(csp) do
      true -> Map.put_new(output, :result, "csp-header-invalid")
      false -> handle_csp(scheme, output, csp, csp_http, csp_meta)
    end
  end

  defp handle_csp(scheme, output, csp, csp_http, _csp_meta) do
    output = %{
      output
      | policy: %{
          antiClickjacking: false,
          defaultNone: false,
          insecureBaseUri: false,
          insecureFormAction: false,
          insecureSchemeActive: false,
          insecureSchemePassive: false,
          strictDynamic: false,
          unsafeEval: false,
          unsafeInline: false,
          unsafeInlineStyle: false,
          unsafeObjects: false
        }
    }

    base_uri = Map.get(csp, "base-uri") || ["*"]

    frame_ancestors =
      if output.http, do: Map.get(csp_http, "frame-ancestors") || ["*"], else: ["*"]

    form_action = Map.get(csp, "form-action") || ["*"]
    object_src = Map.get(csp, "object-src") || Map.get(csp, "default-src") || ["*"]
    script_src = Map.get(csp, "script-src") || Map.get(csp, "default-src") || ["*"]
    style_src = Map.get(csp, "style-src") || Map.get(csp, "default-src") || ["*"]

    script_src = check_for_nonce_or_hash(script_src)
    style_src = check_for_nonce_or_hash(style_src)
    {script_src, output} = check_for_script_dynamic(script_src, output)

    active_csp_sources =
      script_src ++
        Enum.reduce(csp, [], fn {directive, source}, acc ->
          case directive not in @passive_directives and directive != "script-src" do
            true -> source ++ acc
            false -> acc
          end
        end)

    passive_csp_sources =
      Enum.reduce(csp, [], fn {directive, source}, acc ->
        case directive in @passive_directives or directive == "default-src" do
          true -> source ++ acc
          false -> acc
        end
      end)

    # Each list element represents something to check; each element is itself
    # a list with 1) what to check, 2) result and policy to set if the check
    # evaluates to true, and - optionally - 3) result and policy to set if the
    # check evaluates to false.
    checks = [
      [
        nonempty_intersection?(script_src, @dangerously_broad ++ @unsafe_inline) or
          nonempty_intersection?(object_src, @dangerously_broad),
        {"csp-implemented-with-unsafe-inline", :unsafeInline}
      ],
      [
        scheme == "https" and
          Enum.any?(active_csp_sources, &String.contains?(&1, ["http:", "ftp:"])) and
          not output.policy.strictDynamic,
        {"csp-implemented-with-insecure-scheme", :insecureSchemeActive}
      ],
      [
        "'unsafe-eval'" in (script_src ++ style_src),
        {"csp-implemented-with-unsafe-eval", :unsafeEval}
      ],
      [
        scheme == "https" and
          Enum.any?(passive_csp_sources, &String.contains?(&1, ["http:", "ftp:"])),
        {"csp-implemented-with-insecure-scheme-in-passive-content-only", :insecureSchemePassive}
      ],
      [
        nonempty_intersection?(style_src, @dangerously_broad ++ @unsafe_inline),
        {"csp-implemented-with-unsafe-inline-in-style-src-only", :unsafeInlineStyle}
      ],
      [
        nonempty_intersection?(frame_ancestors, @dangerously_broad) == false,
        {nil, :antiClickjacking}
      ],
      [
        nonempty_intersection?(base_uri, @dangerously_broad ++ @unsafe_inline),
        {nil, :insecureBaseUri}
      ],
      [nonempty_intersection?(form_action, @dangerously_broad), {nil, :insecureFormAction}],
      [nonempty_intersection?(object_src, @dangerously_broad), {nil, :unsafeObjects}],
      [
        Enum.member?(Map.get(csp, "default-src", []), "'none'"),
        {"csp-implemented-with-no-unsafe-default-src-none", :defaultNone},
        {"csp-implemented-with-no-unsafe", nil}
      ]
    ]

    Enum.reduce(checks, output, fn x, acc ->
      {result, policy} = Enum.at(x, 1)

      case Enum.at(x, 0) do
        # Each check will, if true, set a result (if none has been set already) and a policy
        true ->
          update_csp_output(acc, result, policy)

        false ->
          # If there's a third list item, it means something should be set if the check is *false*
          case Enum.at(x, 2) != nil do
            true ->
              {result2, policy2} = Enum.at(x, 2)
              update_csp_output(acc, result2, policy2)

            _ ->
              acc
          end
      end
    end)
    |> get_data(csp)
    |> check_result()
  end

  defp get_data(output, csp) do
    case [Map.keys(csp) | Map.values(csp)] |> List.to_string() |> String.length() do
      x when x < 32_768 -> Map.put(output, :data, csp)
      _ -> output
    end
  end

  defp check_result(output) do
    case output.result in [
           output.expectation,
           "csp-implemented-with-no-unsafe-default-src-none",
           "csp-implemented-with-unsafe-inline-in-style-src-only",
           "csp-implemented-with-insecure-scheme-in-passive-content-only"
         ] do
      true -> Map.put(output, :pass, true)
      false -> output
    end
  end

  defp update_csp_output(output, result, policy) do
    output = if result, do: Map.put_new(output, :result, result), else: output

    case output do
      map when is_nil(policy) -> map
      map -> put_in(map, [:policy, policy], true)
    end
  end

  defp nonempty_intersection?(list1, list2) do
    MapSet.intersection(MapSet.new(list1), MapSet.new(list2)) |> MapSet.size() > 0
  end

  defp check_for_nonce_or_hash(src) do
    case Enum.find(src, &String.starts_with?(&1, @nonces_hashes)) do
      nil -> src
      _ -> Enum.reject(src, &(&1 == "'unsafe-inline'"))
    end
  end

  defp check_for_script_dynamic(src, output) do
    if Enum.find(src, &String.starts_with?(&1, @nonces_hashes)) do
      if "'strict-dynamic'" in src do
        new_src =
          Enum.reject(src, fn x ->
            String.starts_with?(x, @dangerously_broad) or x == "'self'" or x == "'unsafe-inline'"
          end)

        {new_src, put_in(output.policy.strictDynamic, true)}
      else
        {src, put_in(output.policy.strictDynamic, true)}
      end
    else
      if "'strict-dynamic'" in src and not Map.has_key?(output, :result) do
        {src, Map.put_new(output, :result, "csp-header-invalid")}
      else
        {src, output}
      end
    end
  end

  def external_report(reg_domain, csp_header, csp_report_only_header, expect_ct_header, nel_header, report_to_header) do
    parsed_csp = parse_csp(csp_header)
    parsed_csp_report_only = parse_csp(csp_report_only_header)

    %{
      csp_report_uri: nil,
      csp_report_only_report_uri: nil,
      csp_report_to: nil,
      csp_report_only_report_to: nil,
      expect_ct: nil,
      nel: nil,
      pass: true
    }
    |> check_csp_report_uri(reg_domain, parsed_csp, :csp_report_uri)
    |> check_csp_report_uri(reg_domain, parsed_csp_report_only, :csp_report_only_report_uri)
    |> check_csp_report_to(reg_domain, parsed_csp, report_to_header, :csp_report_to)
    |> check_csp_report_to(
      reg_domain,
      parsed_csp_report_only,
      report_to_header,
      :csp_report_only_report_to
    )
    |> check_expect_ct(reg_domain, expect_ct_header)
    |> check_nel(reg_domain, nel_header, report_to_header)
  end

  def check_expect_ct(result, _reg_domain, nil) do
    result
  end

  def check_expect_ct(result, reg_domain, expect_ct) do
    case Regex.run(~r/report-uri=\"([^"]*)\"/, expect_ct) do
      [_, url] ->
        if is_third_party_domain?(url, reg_domain) do
          Map.put(result, :expect_ct, url) |> Map.put(:pass, false)
        else
          result
        end

      nil ->
        result
    end
  end

  def check_nel(result, _reg_domain, nil, _report_to_header) do
    result
  end

  def check_nel(result, _reg_domain, _nel_header, nil) do
    result
  end

  def check_nel(result, reg_domain, nel_header, report_to_header) do
    case Jason.decode(nel_header) do
      {:ok, nel_json} ->
        if Map.has_key?(nel_json, "report_to") do
          case Jason.decode("[" <> report_to_header <> "]") do
            {:ok, report_to_json} ->
              parse_report_to(result, reg_domain, report_to_json, :nel, nel_json["report_to"])
            {:error, _} ->
              result
          end
        else
          result
        end
      {:error, _} ->
        result
    end
  end

  def check_csp_report_uri(result, _reg_domain, nil, _csp_header_name) do
    result
  end

  def check_csp_report_uri(result, _reg_domain, csp, _csp_header_name) when not is_map(csp) do
    result
  end

  def check_csp_report_uri(result, reg_domain, csp, csp_header_name) do
    if Map.has_key?(csp, "report-uri") do
      csp_external_urls = Enum.filter(csp["report-uri"], &is_third_party_domain?(&1, reg_domain))

      if Enum.empty?(csp_external_urls) do
        result
      else
        Map.put(result, csp_header_name, csp_external_urls) |> Map.put(:pass, false)
      end
    else
      result
    end
  end

  def check_csp_report_to(result, _reg_domain, csp, report_to_header, _csp_header_name)
      when not is_map(csp) or not is_binary(report_to_header) do
    result
  end

  def check_csp_report_to(result, reg_domain, csp, report_to_header, csp_header_name) do
    if Map.has_key?(csp, "report-to") do
      case Jason.decode("[" <> report_to_header <> "]") do
        {:ok, json} ->
          parse_report_to(result, reg_domain, json, csp_header_name, List.first(csp["report-to"]))

        {:error, _} ->
          result
      end
    else
      result
    end
  end

  def parse_report_to(result, reg_domain, json, header_name, report_group) do
    Enum.reduce(json, result, fn group, acc ->
      case Map.get(group, "group") == report_group and Map.has_key?(group, "endpoints") do
        true ->
          urls =
            group["endpoints"]
            |> Enum.map(fn x -> Map.get(x, "url", "") end)
            |> Enum.filter(&is_third_party_domain?(&1, reg_domain))

          case Enum.empty?(urls) do
            true -> acc
            false -> acc |> Map.put(header_name, urls) |> Map.put(:pass, false)
          end

        false ->
          acc
      end
    end)
  end

  def hsts(nil), do: %{set: false}

  def hsts(header) do
    data = header |> String.slice(0, 1024)
    directives = data |> String.downcase() |> String.split(";") |> Enum.map(&String.trim/1)

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
      nil ->
        map

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
    # 180 days
    if is_integer(map.max_age) && map.max_age >= 15_552_000 do
      %{map | pass: true}
    else
      map
    end
  end

  def x_content_type_options(nil) do
    %{
      name: "X-Content-Type-Options",
      data: nil,
      pass: false,
      result: "x-content-type-options-not-implemented"
    }
  end

  def x_content_type_options(header) do
    data = String.slice(header, 0, 100)

    output = %{
      name: "X-Content-Type-Options",
      data: data,
      pass: false,
      result: nil
    }

    case data |> String.trim() |> String.split(["\n", " "]) |> List.first |> String.downcase() |> String.trim() do
      "nosniff" -> %{output | pass: true, result: "x-content-type-options-nosniff"}
      _ -> %{output | result: "x-content-type-options-header-invalid"}
    end
  end

  def x_frame_options(nil, _csp) do
    %{name: "X-Frame-Options", data: nil, pass: false, result: "x-frame-options-not-implemented"}
  end

  def x_frame_options(header, csp) do
    data = String.slice(header, 0, 100)

    output = %{
      name: "X-Frame-Options",
      data: data,
      pass: false,
      result: nil
    }

    xfo = data |> String.downcase() |> String.trim()

    cond do
      Map.has_key?(csp.data, "frame-ancestors") ->
        %{output | result: "x-frame-options-implemented-via-csp", pass: true}

      xfo in ["deny", "sameorigin"] ->
        %{output | result: "x-frame-options-sameorigin-or-deny", pass: true}

      String.starts_with?(xfo, "allow-from ") ->
        %{output | result: "x-frame-options-allow-from-origin", pass: true}

      true ->
        %{output | result: "x-frame-options-header-invalid"}
    end
  end

  def x_xss_protection(nil, csp) do
    check_xxssp_csp(
      %{
        name: "X-XSS-Protection",
        data: nil,
        pass: false,
        result: "x-xss-protection-not-implemented",
        enabled: false,
        valid: true
      },
      csp
    )
  end

  def x_xss_protection(header, csp) do
    data = String.slice(header, 0, 100)

    output = %{
      name: "X-XSS-Protection",
      data: data,
      pass: false,
      result: nil,
      enabled: false,
      valid: true
    }

    xxp = String.downcase(data)

    output =
      case String.at(xxp, 0) do
        nil -> %{output | valid: false, result: "x-xss-protection-header-invalid"}
        "1" -> %{output | enabled: true}
        "0" -> output
        _ -> %{output | valid: false, result: "x-xss-protection-header-invalid"}
      end

    {output, xxssp} =
      case check_xxssp_directive(data) do
        :error -> {%{output | result: "x-xss-protection-header-invalid", valid: false}, nil}
        result -> {output, result}
      end

    output =
      cond do
        output.valid and output.enabled and Map.get(xxssp, "mode") == "block" ->
          %{output | result: "x-xss-protection-enabled-mode-block", pass: true}

        output.valid and output.enabled ->
          %{output | result: "x-xss-protection-enabled", pass: true}

        output.valid and not output.enabled ->
          %{output | result: "x-xss-protection-disabled"}

        true ->
          output
      end

    check_xxssp_csp(output, csp)
  end

  defp check_xxssp_csp(output, csp) do
    cond do
      output.valid and not output.pass and csp.pass ->
        %{output | pass: true, result: "x-xss-protection-not-needed-due-to-csp"}

      true ->
        output
    end
  end

  def check_xxssp_directive(data) do
    valid_directives = ["0", "1", "mode", "report"]
    valid_modes = ["block"]

    data
    |> String.split(";")
    |> Enum.reduce_while(%{}, fn x, acc ->
      [k, v] =
        case String.contains?(x, "=") do
          true -> x |> String.split("=", parts: 2) |> Enum.map(&String.trim/1)
          false -> [String.trim(x), nil]
        end

      if k not in valid_directives or (k == "mode" and v not in valid_modes) or
           Map.has_key?(acc, k) do
        {:halt, :error}
      else
        {:cont, Map.put(acc, k, v)}
      end
    end)
  end
end
