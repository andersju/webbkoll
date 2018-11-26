# These tests were copied from April King's Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically
# httpobs/tests/unittests/test_headers.py, and Elixir-ified.
#
# License: Mozilla Public License Version 2.0
defmodule Webbkoll.CSPTest do
  use WebbkollWeb.ConnCase
  import Webbkoll.HeaderAnalysis

  test "invalid header" do
    values = [
      "  ",
      "\r\n",
      "",
      # "default-src 'none'; default-src 'none'", # TODO: check for repeated directives?
      # "default-src 'none'; img-src 'self'; default-src 'none'",
      "default-src 'none'; script-src 'strict-dynamic'",
      "defa"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-header-invalid"
      refute output.pass
    end
  end

  test "insecure scheme" do
    values = [
      "default-src http://mozilla.org",
      "default-src 'none'; script-src http://mozilla.org",
      "default-src 'none'; script-src http://mozilla.org",
      "default-src 'none'; script-src ftp://mozilla.org"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-insecure-scheme"
      refute output.pass
      assert output.policy.insecureSchemeActive
    end
  end

  test "insecure scheme in passive content only" do
    values = [
      "default-src 'none'; img-src http://mozilla.org",
      "default-src 'self'; img-src ftp:",
      "default-src 'self'; img-src http:",
      "default-src 'none'; img-src https:; media-src http://mozilla.org",
      "default-src 'none'; img-src http: https:; script-src 'self'; style-src 'self'",
      "default-src 'none'; img-src 'none'; media-src http:; script-src 'self'; style-src 'self'",
      "default-src 'none'; img-src 'none'; media-src http:; script-src 'self'; style-src 'unsafe-inline'"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-insecure-scheme-in-passive-content-only"
      assert output.pass
      assert output.policy.insecureSchemePassive
    end
  end

  test "unsafe inline" do
    values = [
      "script-src 'unsafe-inline'",
      "script-src data:",
      "script-src http:",
      "script-src ftp:",
      "default-src 'unsafe-inline'",
      "default-src 'UNSAFE-INLINE'",
      "DEFAULT-SRC 'none'",
      "script-src 'unsafe-inline'; SCRIPT-SRC 'none'",
      "upgrade-insecure-requests",
      "script-src 'none'",
      "script-src https:",
      "script-src https://mozilla.org https:",
      "default-src https://mozilla.org https:",
      "default-src 'none'; script-src *",
      "default-src *; script-src *; object-src 'none'",
      "default-src 'none'; script-src 'none', object-src *",
      "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval'",
      "default-src 'none'; script-src 'unsafe-inline' http:",
      "object-src https:; script-src 'none'"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-unsafe-inline"
      refute output.pass
      assert output.policy.unsafeInline
    end
  end

  test "unsafe eval" do
    values = [
      "default-src 'none'; script-src 'unsafe-eval'"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-unsafe-eval"
      refute output.pass
      assert output.policy.unsafeEval
    end
  end

  test "unsafe inline in style-src only" do
    values = [
      "object-src 'none'; script-src 'none'; style-src 'unsafe-inline'",
      "default-src 'none'; script-src https://mozilla.org; style-src 'unsafe-inline'",
      "default-src 'unsafe-inline'; script-src https://mozilla.org",
      "default-src 'none';;; ;;;style-src 'self' 'unsafe-inline'",
      "default-src 'none'; style-src data:",
      "default-src 'none'; style-src *",
      "default-src 'none'; style-src https:",
      "default-src 'none'; style-src 'unsafe-inline'; " <>
        "script-src 'sha256-hqBEA/HXB3aJU2FgOnYN8rkAgEVgyfi3Vs1j2/XMPBB=' " <> "'unsafe-inline'"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-unsafe-inline-in-style-src-only"
      assert output.pass
      assert output.policy.unsafeInlineStyle
    end
  end

  test "no unsafe" do
    values = [
      "default-src https://mozilla.org",
      "default-src https://mozilla.org;;; ;;;script-src 'none'",
      "object-src 'none'; script-src https://mozilla.org; " <>
        "style-src https://mozilla.org; upgrade-insecure-requests;",
      "object-src 'none'; script-src 'strict-dynamic' 'nonce-abc' 'unsafe-inline'; style-src 'none'",
      "object-src 'none'; style-src 'self';" <>
        "script-src 'sha256-hqBEA/HXB3aJU2FgOnYN8rkAgEVgyfi3Vs1j2/XMPBA='",
      "object-src 'none'; style-src 'self'; script-src 'unsafe-inline' " <>
        "'sha256-hqBEA/HXB3aJU2FgOnYN8rkAgEVgyfi3Vs1j2/XMPBA='" <>
        "'sha256-hqBEA/HXB3aJU2FgOnYN8rkAgEVgyfi3Vs1j2/XMPBB='",
      "object-src 'none'; script-src 'unsafe-inline' 'nonce-abc123' 'unsafe-inline'; style-src 'none'",
      "default-src https://mozilla.org; style-src 'unsafe-inline' 'nonce-abc123' 'unsafe-inline'",
      "default-src https://mozilla.org; style-src 'unsafe-inline' " <>
        "'sha256-hqBEA/HXB3aJU2FgOnYN8rkAgEVgyfi3Vs1j2/XMPBB=' 'unsafe-inline'"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-no-unsafe"
      assert output.pass
    end
  end

  test "no unsafe default-src none" do
    values = [
      # no value == 'none'
      "default-src",
      "default-src 'none'; script-src 'strict-dynamic' 'nonce-abc123' 'unsafe-inline'",
      "default-src 'none'; script-src https://mozilla.org;" <>
        "style-src https://mozilla.org; upgrade-insecure-requests;",
      "default-src 'none'; object-src https://mozilla.org"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
      assert output.http
      refute output.meta
      assert output.pass
      assert output.policy.defaultNone
    end

    output = csp("https", nil, "default-src 'none';")
    assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
    refute output.http
    assert output.meta
    assert output.pass

    output = csp("https", nil, "default-src 'none';")
    assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
    refute output.http
    assert output.meta
    assert output.pass

    html = File.read!("test/fixtures/test_parse_http_equiv_headers_csp1.html")
    html_headers = Webbkoll.Worker.get_http_equiv_csp(html)
    output = csp("https", nil, html_headers)

    assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
    refute output.http
    assert output.meta
    assert output.pass

    html = File.read!("test/fixtures/test_parse_http_equiv_headers_csp_multiple_http_equiv1.html")
    html_headers = Webbkoll.Worker.get_http_equiv_csp(html)
    output = csp("https", nil, html_headers)

    assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
    refute output.http
    assert output.meta
    assert output.pass

    html = File.read!("test/fixtures/test_parse_http_equiv_headers_csp_multiple_http_equiv1.html")
    html_headers = Webbkoll.Worker.get_http_equiv_csp(html)
    output = csp("https", "script-src https://mozilla.org;", html_headers)

    assert output.result == "csp-implemented-with-no-unsafe-default-src-none"
    assert output.http
    assert output.meta
    assert output.pass
  end

  test "policy analysis" do
    # anticlickjacking disabled
    values = [
      "default-src 'none'",
      "frame-ancestors *",
      "frame-ancestors http:",
      "frame-ancestors https:"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      refute output.policy.antiClickjacking
    end

    # anticlickjacking enabled
    output = csp("https", "default-src *; frame-ancestors 'none'", nil)
    assert output.policy.antiClickjacking

    # unsafeObjects and insecureBaseUri
    values = [
      "default-src 'none'; base-uri *; object-src *",
      "default-src 'none'; base-uri https:; object-src https:",
      "default-src *"
    ]

    for rule <- values do
      output = csp("https", rule, nil)

      assert output.policy.insecureBaseUri
      assert output.policy.unsafeObjects
    end

    # More insecureBaseUri
    values = [
      "default-src *; base-uri 'none'",
      "default-src 'none'; base-uri 'self'",
      "default-src 'none'; base-uri https://mozilla.org"
    ]

    for rule <- values do
      output = csp("https", rule, nil)
      refute output.policy.insecureBaseUri
    end

    # insecureSchemePassive
    values = [
      "default-src * http: https: data: 'unsafe-inline' 'unsafe-eval'",
      "default-src 'none'; img-src http:",
      "default-src 'none' https://mozilla.org; img-src http://mozilla.org",
      "default-src https:; media-src http://mozilla.org; script-src http:"
    ]

    for rule <- values do
      output = csp("https", rule, nil)
      assert output.policy.insecureSchemePassive
    end

    # insecureFormAction
    values = [
      "default-src *; form-action 'none'",
      "default-src *; form-action 'self'",
      "default-src 'none'; form-action 'self' https://mozilla.org",
      "form-action 'self' https://mozilla.org"
    ]

    for rule <- values do
      output = csp("https", rule, nil)
      refute output.policy.insecureFormAction
    end

    values = [
      "default-src *",
      "default-src 'none'",
      "form-action https:"
    ]

    for rule <- values do
      output = csp("https", rule, nil)
      assert output.policy.insecureFormAction
    end
  end
end
