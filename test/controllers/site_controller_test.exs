defmodule Webbkoll.SiteControllerTest do
  use WebbkollWeb.ConnCase
  import Webbkoll.Factory

  @default_locale Application.get_env(:webbkoll, :default_locale)

  test "/ redirects to default locale" do
    conn = get build_conn(), "/"
    assert redirected_to(conn) =~ "/#{@default_locale}/"
  end

  test "index page" do
    conn = get build_conn(), "/en/"
    assert html_response(conn, 200) =~ "How privacy-friendly is your site?"
  end

  test "about page" do
    conn = get build_conn(), "/en/about"
    assert html_response(conn, 200) =~ "Welcome to the Web Privacy Check"
  end

  test "tech page" do
    conn = get build_conn(), "/en/tech"
    assert html_response(conn, 200) =~ "Technology we use"
  end

  test "returns error on domain with TLD not in Public Suffix list" do
    conn = get build_conn(), "/en/check?url=foobar.invalidtld"
    assert html_response(conn, 400) =~ "Error"
  end

  test "returns 302 redirect to status when given valid URL" do
    conn = get build_conn(), "/en/check?url=http://example.com"
    assert List.to_string(Plug.Conn.get_resp_header(conn, "location")) =~ "status"
    assert conn.status == 302
  end

  test "returns 302 redirect to status when given valid domain" do
    conn = get build_conn(), "/en/check?url=example.com"
    assert List.to_string(Plug.Conn.get_resp_header(conn, "location")) =~ "status"
    assert conn.status == 302
  end

  test "analysis+HTML of site with HTTPS, HSTS, CSP, referrer policy, no cookies/external requests" do
    data = read_and_analyze_json("test/fixtures/https_hsts_referrer_no_cookies_or_ext_requests.json")
    site = build(:site, data: data)
    ConCache.put(:site_cache, UUID.uuid4(), site)

    assert data["scheme"] == "https"
    assert data["meta_referrer"] =~ "never"
    assert data["cookie_count"]["first_party"] == 0
    assert data["cookie_count"]["third_party"] == 0
    assert data["third_party_request_count"]["total"] == 0
    assert data["insecure_requests_count"] == 0
    assert data["header_hsts"] =~ "max-age=10886400;"
    assert data["services"] == []

    conn = get build_conn(), "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Results for https://example.com/"
    assert html_response(conn, 200) =~ "Referrers not leaked"
    assert html_response(conn, 200) =~ "uses HTTPS by default"
    assert html_response(conn, 200) =~ "HSTS enabled with value"
    assert html_response(conn, 200) =~ "No first-party cookies"
    assert html_response(conn, 200) =~ "No third-party cookies"
    assert html_response(conn, 200) =~ "No third-party requests"
    assert html_response(conn, 200) =~ "Content-Security-Policy enabled"
  end

  test "site with HTTPS and insecure first-party resource" do
    data = read_and_analyze_json("test/fixtures/mixed_content.json")
    assert data["insecure_requests_count"] == 1
  end

  test "site with HTTP, first and third-party cookies/requests, no referrer policy, no CSP" do
    data = read_and_analyze_json("test/fixtures/http_with_cookies_and_ext_requests.json")
    site = build(:site, data: data)
    ConCache.put(:site_cache, UUID.uuid4(), site)

    assert data["scheme"] == "http"
    assert data["meta_referrer"] == nil
    assert data["header_csp"] == nil
    assert data["cookie_count"]["first_party"] == 13
    assert data["cookie_count"]["third_party"] == 2
    assert data["third_party_request_types"]["insecure"] == 9

    conn = get build_conn(), "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Insecure connection"
    assert html_response(conn, 200) =~ "Referrers leaked"
    assert html_response(conn, 200) =~ "Content-Security-Policy not enabled"
  end

  test "site with Referrer Policy set in Content-Security-Policy header" do
    data = read_and_analyze_json("test/fixtures/csp_referrer.json")

    assert data["referrer_policy"]["status"] == "success"
    assert data["header_csp_referrer"] == "no-referrer"
  end

  test "site with Referrer Policy set in Referrer-Policy header" do
    data = read_and_analyze_json("test/fixtures/referrer_header.json")

    assert data["referrer_policy"]["status"] == "success"
    assert data["header_referrer"] == "no-referrer"
  end

  test "site with Referrer Policy set in both Referrer-Policy and Content-Security-Policy headers (CSP should take precedence)" do
    data = read_and_analyze_json("test/fixtures/csp_and_referrer_header.json")

    assert data["referrer_policy"]["status"] == "alert"
    assert data["header_csp_referrer"] == "unsafe-url"
    assert data["header_referrer"] == "no-referrer"
  end

  test "site with Referrer Policy set in both Content-Security-Policy header and meta element (meta should take precedence)" do
    data = read_and_analyze_json("test/fixtures/csp_and_meta_referrer.json")

    assert data["referrer_policy"]["status"] == "success"
    assert data["header_csp_referrer"] == "unsafe-url"
    assert data["meta_referrer"] == "no-referrer"
  end

  test "site with Content-Security-Policy set in header" do
    data = read_and_analyze_json("test/fixtures/header_csp.json")
    site = build(:site, data: data)
    ConCache.put(:site_cache, UUID.uuid4(), site)

    assert data["header_csp"] == "default-src 'self'"

    conn = get build_conn(), "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Content-Security-Policy enabled"
    assert html_response(conn, 200) =~ "Content-Security-Policy HTTP header is set"
    assert html_response(conn, 200) =~ "default-src 'self'"
  end

  test "site with Content-Security-Policy set in meta element" do
    data = read_and_analyze_json("test/fixtures/meta_csp.json")
    site = build(:site, data: data)
    ConCache.put(:site_cache, UUID.uuid4(), site)

    assert data["meta_csp"] == "default-src 'none'"

    conn = get build_conn(), "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Content-Security-Policy enabled"
    assert html_response(conn, 200) =~ "Content-Security-Policy meta element is set"
    assert html_response(conn, 200) =~ "default-src 'none'"
  end

  test "site with Content-Security-Policy set in both header and meta element (header should take precedence)" do
    data = read_and_analyze_json("test/fixtures/header_csp_and_meta_csp.json")
    site = build(:site, data: data)
    ConCache.put(:site_cache, UUID.uuid4(), site)

    assert data["header_csp"] == "default-src 'self'"
    assert data["meta_csp"] == "default-src 'none'"

    conn = get build_conn(), "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Content-Security-Policy enabled"
    assert html_response(conn, 200) =~ "Content-Security-Policy meta element is set"
    assert html_response(conn, 200) =~ "Content-Security-Policy HTTP header is set"
    assert html_response(conn, 200) =~ "default-src 'self'"
    assert html_response(conn, 200) =~ "default-src 'none'"
    assert html_response(conn, 200) =~ "The HTTP header's policy takes precedence"
  end

  defp read_and_analyze_json(file) do
    file
    |> File.read!
    |> Poison.decode!
    |> Webbkoll.Worker.process_json
  end
end
