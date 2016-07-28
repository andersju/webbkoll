defmodule Webbkoll.SiteControllerTest do
  use Webbkoll.ConnCase
  alias Webbkoll.Factory
  import Webbkoll.Helpers

  @default_locale Application.get_env(:webbkoll, :default_locale)
  @locales Application.get_env(:webbkoll, :locales)

  test "/ redirects to default locale" do
    conn = get build_conn, "/"
    assert redirected_to(conn) =~ "/#{@default_locale}/"
  end

  test "index page" do
    conn = get build_conn, "/en/"
    assert html_response(conn, 200) =~ "How privacy-friendly is your site?"
  end

  test "about page" do
    conn = get build_conn, "/en/about"
    assert html_response(conn, 200) =~ "Welcome to the Web Privacy Check"
  end

  test "tech page" do
    conn = get build_conn, "/en/tech"
    assert html_response(conn, 200) =~ "Technology we use"
  end

  test "returns error on domain with TLD not in Public Suffix list" do
    conn = get build_conn, "/en/check?url=foobar.invalidtld"
    assert html_response(conn, 400) =~ "Error"
  end

  test "returns 302 redirect to status when given valid URL" do
    conn = get build_conn, "/en/check?url=http://example.com"
    assert List.to_string(Plug.Conn.get_resp_header(conn, "location")) =~ "status"
    assert conn.status == 302
  end

  test "returns 302 redirect to status when given valid domain" do
    conn = get build_conn, "/en/check?url=example.com"
    assert List.to_string(Plug.Conn.get_resp_header(conn, "location")) =~ "status"
    assert conn.status == 302
  end

  test "analysis+HTML of site with HTTPS, HSTS, referrer policy, no cookies/external requests" do
    data = read_and_analyze_json("test/fixtures/https_hsts_referrer_no_cookies_or_ext_requests.json")
    site = Factory.insert(:site, input_url: "example.com", final_url: "https://example.com/", data: data)
    site_meta = get_site_meta(site)

    assert site.data["scheme"] == "https"
    assert site.data["meta_referrer"] =~ "never"
    assert site.data["cookie_count"]["first_party"] == 0
    assert site.data["cookie_count"]["third_party"] == 0
    assert site.data["third_party_request_count"]["total"] == 0
    assert site.data["insecure_requests_count"] == 0

    assert site_meta["hsts"] =~ "max-age=10886400;"
    assert site_meta["services"] == []

    conn = get build_conn, "/en/results?url=https%3A%2F%2Fexample.com%2F"
    assert html_response(conn, 200) =~ "Results for https://example.com/"
    assert html_response(conn, 200) =~ "Referrers not leaked"
    assert html_response(conn, 200) =~ "uses HTTPS by default"
    assert html_response(conn, 200) =~ "HSTS enabled with value"
    assert html_response(conn, 200) =~ "No first-party cookies"
    assert html_response(conn, 200) =~ "No third-party cookies"
    assert html_response(conn, 200) =~ "No third-party requests"
  end

  test "site with HTTPS and insecure first-party resource" do
    data = read_and_analyze_json("test/fixtures/mixed_content.json")
    assert data["insecure_requests_count"] == 1
  end

  test "site with HTTP, first and third-party cookies/requests, no referrer policy" do
    data = read_and_analyze_json("test/fixtures/http_with_cookies_and_ext_requests.json")

    assert data["scheme"] == "http"
    assert data["meta_referrer"] == ""
    assert data["cookie_count"]["first_party"] == 13
    assert data["cookie_count"]["third_party"] == 2
    assert data["third_party_request_types"]["insecure"] == 9
  end

  defp read_and_analyze_json(file) do
    file
    |> File.read!
    |> Poison.decode!
    |> Webbkoll.Worker.process_json
  end
end
