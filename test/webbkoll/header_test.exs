# These tests were copied from April King's Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically
# httpobs/tests/unittests/test_headers.py, and Elixir-ified.
#
# License: Mozilla Public License Version 2.0
defmodule Webbkoll.HeaderTest do
  use WebbkollWeb.ConnCase
  import Webbkoll.HeaderAnalysis

  test "X-Content-Type header missing" do
    output = x_content_type_options(nil)

    assert output.result == "x-content-type-options-not-implemented"
    refute output.pass
  end

  test "X-Content-Type header invalid" do
    for value <- ["", "foobar", "nosniff,nosniff"] do
      output = x_content_type_options(value)

      assert output.result == "x-content-type-options-header-invalid"
      refute output.pass
    end
  end

  test "X-Content-Type header valid" do
    for value <- ["nosniff", " nosniff", "nosniff ", " nosniff "] do
      output = x_content_type_options(value)

      assert output.result == "x-content-type-options-nosniff"
      assert output.pass
    end
  end

  test "X-Frame-Options header missing" do
    output = x_frame_options(nil, csp("", "", nil))

    assert output.result == "x-frame-options-not-implemented"
    refute output.pass
  end

  test "X-Frame-Options header invalid" do
    for value <- ["FOOBAR", "SAMEORIGIN, SAMEORIGIN"] do
      output = x_frame_options(value, csp("", "", nil))

      assert output.result == "x-frame-options-header-invalid"
      refute output.pass
    end
  end

  test "X-Frame-Options header allow from origin" do
    output = x_frame_options("ALLOW-FROM https://dataskydd.net", csp("", "", nil))

    assert output.result == "x-frame-options-allow-from-origin"
    assert output.pass
  end

  test "X-Frame-Options deny" do
    for value <- ["DENY", "DENY "] do
      output = x_frame_options(value, csp("", "", nil))

      assert output.result == "x-frame-options-sameorigin-or-deny"
      assert output.pass
    end
  end

  test "X-Frame-Options enabled via CSP" do
    output = x_frame_options("DENY", csp("https", "frame-ancestors https://dataskydd.net", nil))

    assert output.result == "x-frame-options-implemented-via-csp"
    assert output.pass
  end

  test "X-XSS-Protection header missing" do
    output = x_xss_protection(nil, csp("", "", nil))

    assert output.result == "x-xss-protection-not-implemented"
    refute output.pass
  end

  test "X-XSS-Protection header invalid" do
    for value <- [
          "foobar",
          "2; mode=block",
          "1; mode=block; mode=block",
          "1; mode=block, 1; mode=block"
        ] do
      output = x_xss_protection(value, csp("", "", nil))

      assert output.result == "x-xss-protection-header-invalid"
      refute output.pass
    end
  end

  test "X-XSS-Protection header disabled" do
    output = x_xss_protection("0", csp("", "", nil))

    assert output.result == "x-xss-protection-disabled"
    refute output.pass
  end

  test "X-XSS-Protection enabled with no blocking" do
    for value <- ["1", "1 "] do
      output = x_xss_protection(value, csp("", "", nil))

      assert output.result == "x-xss-protection-enabled"
      assert output.pass
    end
  end

  test "X-XSS-Protection enabled with blocking" do
    output = x_xss_protection("1; mode=block", csp("", "", nil))

    assert output.result == "x-xss-protection-enabled-mode-block"
    assert output.pass
  end

  test "X-XSS-Protection enabled via CSP" do
    csp_output = csp("https", "object-src 'none'; script-src 'none'", nil)
    output = x_xss_protection(nil, csp_output)

    assert output.result == "x-xss-protection-not-needed-due-to-csp"
    assert output.pass
  end

  test "Content-Security-Policy with third-party report-uri" do
    output = external_report("dataskydd.net", "default-src https:; report-uri https://not-dataskydd.net/", "", "", "", "")

    assert output.csp_report_uri == ["https://not-dataskydd.net/"]
    assert output.csp_report_only_report_uri == nil
    assert output.pass == false
  end

  test "Content-Security-Policy with first-party report-uri" do
    output = external_report("dataskydd.net", "default-src https:; report-uri https://dataskydd.net/", "", "", "", "")

    assert output.csp_report_uri == nil
    assert output.pass == true
  end

  test "Content-Security-Policy-Report-Only with third-party report-uri" do
    output = external_report("dataskydd.net", "", "default-src https:; report-uri https://not-dataskydd.net/", "", "", "")

    assert output.csp_report_only_report_uri == ["https://not-dataskydd.net/"]
    assert output.csp_report_uri == nil
    assert output.pass == false
  end

  test "Content-Security-Policy-Report-Only with first-party report-uri" do
    output = external_report("dataskydd.net", "", "default-src https:; report-uri https://dataskydd.net/", "", "", "")

    assert output.csp_report_only_report_uri == nil
    assert output.pass == true
  end

  test "Content-Security-Policy with third-party report-to endpoint" do
    output = external_report("dataskydd.net", "default-src https:; report-to default", "", "", "", ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://not-dataskydd.net/"}]}|)

    assert output.csp_report_to == ["https://not-dataskydd.net/"]
    assert output.csp_report_only_report_to == nil
    assert output.pass == false
  end

  test "Content-Security-Policy with first-party report-to endpoint" do
    output = external_report("dataskydd.net", "default-src https:; report-to default", "", "", "", ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://dataskydd.net/"}]}|)

    assert output.csp_report_to == nil
    assert output.csp_report_only_report_to == nil
    assert output.pass == true
  end

  test "Content-Security-Policy-Report-Only with third-party report-to endpoint" do
    output = external_report("dataskydd.net", "", "default-src https:; report-to default", "", "", ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://not-dataskydd.net/"}]}|)

    assert output.csp_report_to == nil
    assert output.csp_report_only_report_to == ["https://not-dataskydd.net/"]
    assert output.pass == false
  end

  test "Content-Security-Policy-Report-Only with first-party report-to endpoint" do
    output = external_report("dataskydd.net", "", "default-src https:; report-to default", "", "", ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://dataskydd.net/"}]}|)

    assert output.csp_report_to == nil
    assert output.csp_report_only_report_to == nil
    assert output.pass == true
  end

  test "Expect-CT with third-party report-uri" do
    output = external_report("dataskydd.net", "", "", ~s|max-age=86400, enforce, report-uri="https://not-dataskydd.net/"|, "", "")

    assert output.expect_ct == "https://not-dataskydd.net/"
    assert output.pass == false
  end

  test "Expect-CT with first-party report-uri" do
    output = external_report("dataskydd.net", "", "", ~s|max-age=86400, enforce, report-uri="https://dataskydd.net/"|, "", "")

    assert output.expect_ct == nil
    assert output.pass == true
  end

  test "NEL with third-party report-to endpoint" do
    output = external_report("dataskydd.net", "", "", "", ~s|{"report_to": "default", "max_age": 2592000}|, ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://not-dataskydd.net/"}]}|)

    assert output.nel == ["https://not-dataskydd.net/"]
    assert output.pass == false
  end

  test "NEL with first-party report-to endpoint" do
    output = external_report("dataskydd.net", "", "", "", ~s|{"report_to": "default", "max_age": 2592000}|, ~s|{"group": "default", "max_age": 2592000, "endpoints": [{"url": "https://dataskydd.net/"}]}|)

    assert output.nel == nil
    assert output.pass == true
  end
end
