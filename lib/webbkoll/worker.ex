defmodule Webbkoll.Worker do
  alias Webbkoll.{Site, Repo}
  import Ecto.Query
  import Webbkoll.Helpers

  @max_retries Application.get_env(:exq, :max_retries)

  def perform(id, url, refresh, backend_url) do
    update_site(id, %{status: "processing"})

    # TODO: Stop having try_count in db once exq gets
    # job introspection (https://github.com/akira/exq/issues/155)
    Site
    |> where(id: ^id)
    |> update(inc: [try_count: 1])
    |> Repo.update_all([])

    url
    |> fetch(refresh, backend_url)
    |> handle_response(id)
    |> decode_response(id)
    |> process_json
    |> save(id)
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
        "on" -> %{fetch_url: url, parse_delay: 10000, get_requests: "true",
                  get_cookies: "true", force: "true"}
        _    -> %{fetch_url: url, parse_delay: 10000,
                  get_requests: "true", get_cookies: "true"}
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
    site = Repo.get(Site, id)
    if site.try_count > @max_retries ||
    String.ends_with?(reason, ["not found", "Connection refused"]) do
      update_site(id, %{status: "failed", status_message: reason})
    end
    raise WorkerError, message: reason
  end

  def process_json(json) do
    with url = URI.parse(json["final_url"]),
         reg_domain = get_registerable_domain(url.host),
         cookies = get_cookies(json["cookies"], reg_domain),
         third_party_requests = get_third_party_requests(json["requests"], reg_domain),
         insecure_first_party_requests = get_insecure_first_party_requests(json["requests"], reg_domain),
         third_party_request_types = get_request_types(third_party_requests)
    do
      %{"input_url" => json["input_url"],
        "final_url" => json["final_url"],
        "scheme" => url.scheme,
        "cookies" => cookies,
        "cookie_count" => get_cookie_count(cookies),
        "cookie_domains" => Enum.count(get_unique_hosts(cookies["third_party"], "domain")),
        "insecure_first_party_requests" => insecure_first_party_requests,
        "third_party_requests" => third_party_requests,
        "third_party_request_types" => third_party_request_types,
        "third_party_request_count" => get_request_count(third_party_requests),
        "insecure_requests_count" => third_party_request_types["insecure"] + Enum.count(insecure_first_party_requests),
        "meta_referrer" => get_meta_referrer(json["content"]),
        "headers" => json["response_headers"]}
     end
  end

  defp save(data, id) do
    update_site(id, %{status: "done", final_url: data["final_url"], data: data})
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

  defp get_meta_referrer(content) do
    content
    |> Floki.find("meta[name='referrer']")
    |> Floki.attribute("content")
    |> List.to_string
    |> case do
         "" -> nil
         value -> value
       end
  end
end

defmodule WorkerError do
  defexception message: "Something bad went down."
end
