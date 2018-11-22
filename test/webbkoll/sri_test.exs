# These tests were copied from April King's Mozilla HTTP Observatory
# (https://github.com/mozilla/http-observatory), specifically
# httpobs/tests/unittests/test_content.py, and Elixir-ified.
# License: Mozilla Public License Version 2.0
defmodule Webbkoll.SRITest do
  use WebbkollWeb.ConnCase
  import Webbkoll.ContentAnalysis

  test "no scripts" do
    html = File.read!("test/fixtures/test_content_sri_no_scripts.html")
    output = check_sri(html, "", "")

    assert output.result == "sri-not-implemented-but-no-scripts-loaded"
    assert output.pass
  end

  test "same origin" do
    html = File.read!("test/fixtures/test_content_sri_sameorigin1.html")
    output = check_sri(html, "", "")

    assert output.result == "sri-not-implemented-but-all-scripts-loaded-from-secure-origin"
    assert output.pass

    html = File.read!("test/fixtures/test_content_sri_sameorigin2.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-not-implemented-but-all-scripts-loaded-from-secure-origin"
    assert output.pass

    html = File.read!("test/fixtures/test_content_sri_sameorigin3.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-not-implemented-and-external-scripts-not-loaded-securely"
    refute output.pass
  end

  test "test page with SRI and external scripts" do
    html = File.read!("test/fixtures/test_content_sri_impl_external_https1.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-implemented-and-external-scripts-loaded-securely"
    assert output.pass

    html = File.read!("test/fixtures/test_content_sri_impl_external_https2.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-implemented-and-external-scripts-loaded-securely"
    assert output.pass
  end

  test "page with SRI on same origin" do
    html = File.read!("test/fixtures/test_content_sri_impl_sameorigin.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-implemented-and-all-scripts-loaded-securely"
    assert output.pass
  end

  test "page with external HTTPS scripts and no SRI" do
    html = File.read!("test/fixtures/test_content_sri_notimpl_external_https.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-not-implemented-but-external-scripts-loaded-securely"
    refute output.pass
  end

  test "page with external HTTP scripts and SRI" do
    html = File.read!("test/fixtures/test_content_sri_impl_external_http.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-implemented-but-external-scripts-not-loaded-securely"
    refute output.pass
  end

  test "page with external scripts with no protocol specified and with SRI" do
    html = File.read!("test/fixtures/test_content_sri_impl_external_noproto.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-implemented-but-external-scripts-not-loaded-securely"
    refute output.pass
  end

  test "page with external HTTP scripts and no SRI" do
    html = File.read!("test/fixtures/test_content_sri_notimpl_external_http.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-not-implemented-and-external-scripts-not-loaded-securely"
    refute output.pass
  end

  test "page with external scripts with no protocol specified and no SRI" do
    html = File.read!("test/fixtures/test_content_sri_notimpl_external_noproto.html")
    output = check_sri(html, "dataskydd.net", "https")

    assert output.result == "sri-not-implemented-and-external-scripts-not-loaded-securely"
    refute output.pass
  end
end