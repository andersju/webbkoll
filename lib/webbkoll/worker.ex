defmodule Webbkoll.Worker do
  import Webbkoll.Helpers

  @max_attempts Application.get_env(:webbkoll, :max_attempts)

  def perform(id, url, refresh, backend_url) do
    %{status: status} = ConCache.get(:site_cache, id)

    if status != "failed" do
      update_site(id, %{status: "processing"})

      ConCache.update(:site_cache, id, fn old ->
        {:ok, old |> Map.update(:try_count, 0, &(&1 + 1))}
      end)

      url
      |> check_if_https_only
      |> fetch(refresh, backend_url)
      |> handle_response(id)
      |> decode_response(id)
      |> process_json
      |> save(id)
    end
  end

  # By default, the get_proper_url plug in SiteController makes sure all URLs are
  # http:// no matter what (even if user enters https:// in our form); this is to
  # check whether a site redirects to HTTPS by default. However, a small (but
  # probably increasing) amount of sites don't do insecure HTTP *at all*. This is
  # a somewhat crude way to deal with that edge case.
  defp check_if_https_only(url) do
    case HTTPoison.head(url) do
      {:error, %{reason: :econnrefused}} -> get_https_url(url)
      {:error, %{reason: :connect_timeout}} -> get_https_url(url)
      _ -> url
    end
  end

  defp get_https_url(url) do
    url
    |> URI.parse()
    |> Map.put(:scheme, "https")
    |> Map.put(:port, 443)
    |> URI.to_string()
  end

  def update_site(id, params) do
    ConCache.update(:site_cache, id, fn old ->
      {
        :ok,
        old |> Map.merge(params) |> Map.merge(%{updated_at: System.system_time(:microsecond)})
      }
    end)
  end

  def fetch(url, refresh, backend_url) do
    params =
      case refresh do
        "on" ->
          %{
            fetch_url: url,
            timeout: 15000
          }

        _ ->
          %{fetch_url: url, timeout: 15000}
      end

    HTTPoison.get(backend_url, [], recv_timeout: 30000, params: params)
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
    site = ConCache.get(:site_cache, id)

    # Usually we should try again because Chrome/Chromium might not be totally stable,
    # but sometimes - e.g. when user has entered an invalid domain name - it's
    # better not to, and to instead give feedback right away.
    if site.try_count >= @max_attempts ||
         String.contains?(reason, ["404", "ERR_CONNECTION_REFUSED", "ERR_NAME_NOT_RESOLVED"]) do
      update_site(id, %{status: "failed", status_message: reason})
    end

    raise reason
  end

  def process_json(json) do
    with url = URI.parse(json["final_url"]),
         reg_domain = get_registerable_domain(url.host),
         headers = json["response_headers"],
         cookies = get_cookies(json["cookies"], reg_domain),
         # Ignore first request in requests list, as it's by definition a first-party request;
         # fixes issue with IDN domains
         third_party_requests = get_third_party_requests(tl(json["requests"]), reg_domain),
         insecure_first_party_requests =
           get_insecure_first_party_requests(json["requests"], reg_domain),
         third_party_request_types = get_request_types(third_party_requests),
         host_ip = get_ip_by_host(url.host),
         meta_referrer = get_meta(json["content"], "name", "referrer"),
         header_csp_referrer =
           headers
           |> get_header("content-security-policy")
           |> get_by_regex(~r/\breferrer ([\w-]+)\b/),
         header_referrer =
           headers
           |> get_header("referrer-policy"),
         referrer_policy_in_use =
           check_referrer_policy_in_use(meta_referrer, header_csp_referrer, header_referrer) do
      %{
        "input_url" => json["input_url"],
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
        "insecure_requests_count" =>
          third_party_request_types["insecure"] + Enum.count(insecure_first_party_requests),
        "meta_referrer" => meta_referrer,
        "meta_csp" => get_meta(json["content"], "http-equiv", "content-security-policy"),
        "header_csp" => get_header(headers, "content-security-policy"),
        "header_csp_referrer" => header_csp_referrer,
        "header_hsts" => headers["strict-transport-security"],
        "header_referrer" => header_referrer,
        "referrer_policy" => check_referrer_policy(referrer_policy_in_use),
        "services" => check_services(third_party_requests)
      }
    end
  end

  defp save(data, id) do
    update_site(id, %{
      status: "done",
      input_url: data["input_url"],
      final_url: data["final_url"],
      data: data
    })
  end

  defp get_registerable_domain(host) do
    case PublicSuffix.matches_explicit_rule?(host) do
      true -> PublicSuffix.registrable_domain(host)
      false -> host
    end
  end

  defp get_insecure_first_party_requests(requests, registerable_domain) do
    requests
    |> Enum.reduce([], fn request, acc -> check_insecure_first_party(request, acc, registerable_domain) end)
    |> get_insecure_first_party_requests()
  end

  defp get_insecure_first_party_requests([]), do: []
  # We force the first request to be insecure, so remove it
  defp get_insecure_first_party_requests(list) when is_list(list), do: tl(list)

  def check_insecure_first_party(request, acc, registerable_domain) do
    parsed_url = URI.parse(request["url"])

    case is_insecure_first_party?(parsed_url, registerable_domain) do
      true -> [Map.put(request, "host", parsed_url.host) | acc]
      false -> acc
    end
  end

  defp is_insecure_first_party?(parsed_url, registerable_domain) do
    parsed_url.host !== nil && get_registerable_domain(parsed_url.host) == registerable_domain &&
      parsed_url.scheme == "http"
  end

  defp get_third_party_requests(requests, registerable_domain) do
    Enum.reduce(requests, [], fn request, acc ->
      host = URI.parse(request["url"]).host
      case host !== nil && get_registerable_domain(host) !== registerable_domain do
        true -> [Map.put(request, "host", host) | acc]
        false -> acc
      end
    end)
  end

  defp get_request_types(requests) do
    total = Enum.count(requests)
    secure = Enum.count(requests, fn request -> String.starts_with?(request["url"], "https://") end)
    unique_hosts = requests |> get_unique_hosts("host") |> Enum.count()

    %{"total" => total, "secure" => secure, "insecure" => total - secure, "unique_hosts" => unique_hosts}
  end

  defp get_cookies(cookies, registerable_domain) do
    cookies
    |> Enum.split_with(fn cookie -> split_by_domain(cookie, registerable_domain) end)
    |> (&(%{"first_party" => elem(&1, 0), "third_party" => elem(&1, 1)})).()
  end

  defp split_by_domain(x, registerable_domain) do
    (x["domain"] |> String.trim(".") |> get_registerable_domain()) == registerable_domain
  end

  defp get_cookie_count(cookies) do
    %{
      "first_party" => Enum.count(cookies["first_party"]),
      "third_party" => Enum.count(cookies["third_party"])
    }
  end

  defp get_meta(content, attribute, name) do
    content
    |> String.downcase()
    |> Floki.find("meta[#{attribute}='#{name}']")
    |> Floki.attribute("content")
    |> List.last()
    |> get_meta()
  end

  defp get_meta(""), do: nil
  defp get_meta(value), do: value

  defp get_header(headers, header) do
    case Map.has_key?(headers, header) do
      true -> Map.get(headers, header)
      false -> nil
    end
  end

  defp get_by_regex(nil, _), do: nil

  defp get_by_regex(string, regex) do
    case Regex.run(regex, string) do
      [_, value] -> value
      nil -> nil
    end
  end

  defp get_geolocation_by_ip(nil), do: nil

  defp get_geolocation_by_ip(ip) do
    ip
    |> Geolix.lookup(as: :raw, where: :country, locale: :en)
    |> get_in([:country, :iso_code])
  end

  defp get_ip_by_host(host) do
    host
    |> String.to_charlist()
    |> :inet.gethostbyname()
    |> case do
      {:error, _} -> nil
      # TODO: If host resolves to multiple IPs, we currently only show the first one.
      # Should be fixed.
      {:ok, {:hostent, _, _, :inet, 4, ip}} -> List.first(ip) |> Tuple.to_list() |> Enum.join(".")
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

  defp check_referrer_policy(referrer_string) do
    # If multiple policy values are specified, use the last one
    # (https://www.w3.org/TR/referrer-policy/#parse-referrer-policy-from-header)
    referrer =
      if referrer_string do
        String.split(referrer_string)
        |> List.last()
        |> get_by_regex(~r/^([\w-]+);?$/i)
      else
        ""
      end

    cond do
      referrer in ["never", "no-referrer", "same-origin"] ->
        %{"status" => "success", "icon" => "icon-umbrella2 success"}

      referrer in [
        "origin",
        "origin-when-cross-origin",
        "origin-when-crossorigin",
        "strict-origin",
        "strict-origin-when-cross-origin"
      ] ->
        %{"status" => "warning", "icon" => "icon-raindrops2 warning"}

      referrer in ["no-referrer-when-down-grade", "default", "unsafe-url", "always", "", nil] ->
        %{"status" => "alert", "icon" => "icon-raindrops2 alert"}

      true ->
        %{"status" => "other", "icon" => ""}
    end
  end
end
