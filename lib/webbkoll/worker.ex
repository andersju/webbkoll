defmodule Webbkoll.Worker do
  alias WebbkollWeb.Site
  alias Webbkoll.Repo
  import Webbkoll.Helpers
  import WebbkollWeb.Gettext

  @max_retries Application.get_env(:exq, :max_retries)

  def perform(id, url, refresh, backend_url) do
    update_site(id, %{status: "processing"})

    url
    |> check_if_https_only
    |> fetch(refresh, backend_url)
    |> handle_response(id)
    |> decode_response(id)
    |> process_json
    |> save(id)
  end

  # By default, the get_proper_url plug in SiteController makes sure all URLs are
  # http:// no matter what (even if user enters https:// in our form); this is to
  # check whether a site redirects to HTTPS by default. However, a small (but
  # probably increasing) amount of sites don't do insecure HTTP *at all*. This is
  # a somewhat crude way to deal with that edge case.
  defp check_if_https_only(url) do
    case HTTPoison.head(url) do
      {:error, %{reason: :econnrefused}} -> get_https_url(url)
      _ -> url
    end
  end

  defp get_https_url(url) do
    url
    |> URI.parse
    |> Map.put(:scheme, "https")
    |> Map.put(:port, 443)
    |> URI.to_string
  end

  defp update_site(id, params) do
    Site
    |> Repo.get(id)
    |> Site.changeset(params)
    |> Repo.update
    |> handle_update
  end

  defp handle_update({:ok, site}), do: site
  defp handle_update({:error, changeset}), do: IO.inspect changeset

  def fetch(url, refresh, backend_url) do
    params =
      case refresh do
        "on" -> %{fetch_url: url, parse_delay: 10_000, get_requests: "true",
                  get_cookies: "true", force: "true"}
        _    -> %{fetch_url: url, parse_delay: 10_000,
                  get_requests: "true", get_cookies: "true"}
      end
    HTTPoison.get(backend_url, [], recv_timeout: 30_000, params: params)
  end

  defp handle_response({:ok, %{status_code: 200, body: body}}, _id) do
    {:ok, Poison.decode!(body)}
  end
  defp handle_response({:ok, %{status_code: _, body: body}}, _id) do
    {:error, Poison.decode!(body)}
  end
  defp handle_response({:error, %{reason: reason}}, id) do
    handle_error(to_string(reason), id)
  end

  defp decode_response({:ok, body}, _id) do
    body
  end
  defp decode_response({:error, %{"reason" => reason}}, id) do
    handle_error(reason, id)
  end

  defp handle_error(reason, id) do
    job = Exq.worker_job()

    # Usually we should try again because PhantomJS sometimes randomly fails,
    # but sometimes - e.g. when user has entered an invalid domain name - it's
    # better not to, and to give feedback right away. Ideally (?) we should then
    # remove the job from exq's queue, but that doesn't appear to work (or I'm
    # missing something) -- so in certain cases exq will try again, even after
    # user has been shown the Failed page.
    if job.retry_count == @max_retries ||
    String.ends_with?(reason, ["not found", "Connection refused"]) do
      update_site(id, %{status: "failed", status_message: reason})
    end

    raise WorkerError, message: reason
  end

  def process_json(json) do
    with url = URI.parse(json["final_url"]),
         reg_domain = get_registerable_domain(url.host),
         headers = json["response_headers"],
         cookies = get_cookies(json["cookies"], reg_domain),
         third_party_requests = get_third_party_requests(json["requests"], reg_domain),
         insecure_first_party_requests = get_insecure_first_party_requests(json["requests"], reg_domain),
         third_party_request_types = get_request_types(third_party_requests),
         host_ip = get_ip_by_host(url.host),
         meta_referrer = get_meta(json["content"], "name", "referrer"),
         header_csp_referrer = check_csp_referrer(headers),
         header_referrer = check_referrer_header(headers),
         referrer_policy_in_use = check_referrer_policy_in_use(meta_referrer, header_csp_referrer, header_referrer)
    do
      %{"input_url" => json["input_url"],
        "final_url" => json["final_url"],
        "reg_domain" => reg_domain,
        "host" => url.host,
        "host_ip" => host_ip,
        "geolocation" => get_geolocation_by_ip(host_ip),
        "scheme" => url.scheme,
        "headers" => headers,
        "cookies" => cookies,
        "cookie_count" => get_cookie_count(cookies),
        "cookie_domains" => Enum.count(get_unique_hosts(cookies["third_party"], "domain")),
        "insecure_first_party_requests" => insecure_first_party_requests,
        "third_party_requests" => third_party_requests,
        "third_party_request_types" => third_party_request_types,
        "third_party_request_count" => get_request_count(third_party_requests),
        "insecure_requests_count" => third_party_request_types["insecure"] + Enum.count(insecure_first_party_requests),
        "meta_referrer" => meta_referrer,
        "meta_csp" => get_meta(json["content"], "http-equiv", "content-security-policy"),
        "header_csp" => get_header(headers, "content-security-policy"),
        "header_csp_referrer" => header_csp_referrer,
        "header_hsts" => headers["strict-transport-security"],
        "header_referrer" => check_referrer_header(headers),
        "referrer_policy" => check_referrer_policy(referrer_policy_in_use),
        "services" => check_services(third_party_requests)}
     end
  end

  defp save(data, id) do
    update_site(id, %{status: "done", input_url: data["input_url"], final_url: data["final_url"], data: data})
  end

  defp get_registerable_domain(host) do
    case PublicSuffix.matches_explicit_rule?(host) do
      true  -> PublicSuffix.registrable_domain(host)
      false -> host
    end
  end

  defp get_insecure_first_party_requests(requests, registerable_domain) do
    Enum.reduce(requests, [], fn(x, acc) ->
      parsed_url = URI.parse(x["url"])
      if parsed_url.host !== nil && get_registerable_domain(parsed_url.host) == registerable_domain &&
      parsed_url.scheme == "http" do
        acc ++ [Map.put(x, "host", parsed_url.host)]
      else
        acc
      end
    end)
    |> case do
         [] -> []
         list -> tl(list) # We force the first request to be insecure, so remove it
       end
  end

  defp get_third_party_requests(requests, registerable_domain) do
    Enum.reduce(requests, [], fn(x, acc) ->
      host = URI.parse(x["url"]).host
      if host !== nil && get_registerable_domain(host) !== registerable_domain do
        acc ++ [Map.put(x, "host", host)]
      else
        acc
      end
    end)
  end

  defp get_request_types(requests) do
    Enum.reduce(requests, %{"secure" => 0, "insecure" => 0}, fn(x, acc) ->
      case String.starts_with?(x["url"], "https") do
        true -> Map.put(acc, "secure", acc["secure"] + 1)
        false -> Map.put(acc, "insecure", acc["insecure"] + 1)
      end
    end)
  end

  def get_request_count(requests) do
    %{"total"         => Enum.count(requests),
      "unique_hosts"  => requests |> get_unique_hosts("host") |> Enum.count}
  end

  defp get_cookies(cookies, registerable_domain) do
    {first, third} =
      Enum.split_with(cookies, fn(x) ->
        (x["domain"] |> String.trim(".") |> get_registerable_domain) == registerable_domain
      end)
    %{"first_party" => first, "third_party" => third}
  end

  defp get_cookie_count(cookies) do
    %{"first_party" => Enum.count(cookies["first_party"]),
      "third_party" => Enum.count(cookies["third_party"])}
  end

  defp get_meta(content, attribute, name) do
    content
    |> String.downcase
    |> Floki.find("meta[#{attribute}='#{name}']")
    |> Floki.attribute("content")
    |> List.to_string
    |> case do
         "" -> nil
         value -> value
       end
  end

  defp get_header(headers, header) do
    if Map.has_key?(headers, header) do
      Map.get(headers, header)
    else
      nil
    end
  end

  defp get_geolocation_by_ip(nil) do
    nil
  end
  defp get_geolocation_by_ip(ip) do
    ip
    |> Geolix.lookup([as: :raw, where: :country, locale: :en])
    |> get_in([:country, :iso_code])
  end

  defp get_ip_by_host(host) do
    host
    |> String.to_charlist
    |> :inet.gethostbyname
    |> case do
         {:error, _} -> nil
         {:ok, hostent} -> hostent |> elem(5) |> hd |> Tuple.to_list |> Enum.join(".")
       end
  end

  defp check_referrer_policy_in_use(meta, csp, referrer_header) do
    # Precedence in Firefox 50
    cond do
      meta -> meta
      csp -> csp
      referrer_header -> referrer_header
      true -> nil
    end
  end

  defp check_csp_referrer(headers) do
    if Map.has_key?(headers, "content-security-policy") do
      case Regex.run(~r/\breferrer ([\w-]+)\b/, headers["content-security-policy"]) do
           [_, value] -> value
           nil -> nil
      end
    else
      nil
    end
  end

  defp check_referrer_header(headers) do
    if Map.has_key?(headers, "referrer-policy") do
      case Regex.run(~r/^([\w-]+)$/i, headers["referrer-policy"]) do
           [_, value] -> value
           nil -> nil
      end
    else
      nil
    end
  end

  defp check_referrer_policy(referrer) do
    cond do
      referrer in ["never", "no-referrer"] ->
        %{"status" => "success",
          "icon"   => "icon-umbrella2 success",
          "text"   => gettext("Referrers not leaked")}
      referrer in ["origin", "origin-when-cross-origin", "origin-when-crossorigin"] ->
        %{"status" => "warning",
          "icon"   => "icon-raindrops2 warning",
           "text"  => gettext("Referrers partially leaked")}
      referrer in ["no-referrer-when-down-grade", "default", "unsafe-url", "always", "", nil] ->
        %{"status" => "alert",
          "icon" => "icon-raindrops2 alert",
           "text" => gettext("Referrers leaked")}
      true ->
        %{"status" => "other",
          "icon" => "",
          "text" => gettext("Referrers are (probably) leaked")}
    end
  end
end

defmodule WorkerError do
  defexception message: "Something bad went down."
end
