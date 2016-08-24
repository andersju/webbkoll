defmodule Webbkoll.Helpers do
  import Webbkoll.Gettext

  def check_services(nil), do: []
  def check_services(requests) do
    requests
    |> Enum.reduce([], fn(request, acc) ->
      Enum.reduce(services, acc, fn({k, v}, acc) ->
        case String.contains?(request["url"], v["pattern"]) do
          true -> acc ++ [k]
          false -> acc
        end
      end)
    end)
    |> Enum.uniq
  end

  def get_service(service, key) do
    if Map.has_key?(services, service) do
      services[service][key]
    end
  end

  # TODO: Would be nicer to have this in a JSON file, but then gettext
  # becomes complicated (?)
  defp services do
    %{
      "cdn" =>
        %{"pattern" => ["code.jquery.com", "ajax.googleapis.com/ajax/libs", "ajax.aspnetcdn.com", "cdnjs.cloudflare.com", "maxcdn.bootstrapcdn.com"],
        "description" => gettext(~s{The site is loading libraries from one or more CDN:s.}),
        "alternative" => gettext(~s{Self-host the files.})},

      "disqus" =>
        %{"pattern" => ["disqus.com"],
        "description" => gettext(~s{The site is using the Disqus comment system.}),
        "alternative" => gettext(~s{Consider a self-hosted platform.})},

      "google-analytics" =>
        %{"pattern" => ["google-analytics.com"],
        "description" => gettext(~s{The site is using Google Analytics. While this is a powerful tool, we think you should respect your users' privacy and not tell Google about them &mdash; at least not without your users' consent.}),
        "alternative" => gettext(~s{Piwik is an excellent alternative. It's free software (PHP & MySQL) and you run it on your own server, meaning <em>you</em> are in control of the data. It offers various privacy settings and, unlike Google Analytics, it can be used without cookies. <em>(While analytics might be considered essential by some websites, another alternative is <em>don't track people just because you can</em>. Visitors do not, in fact, have an implicit obligation to help you optimize things.)</em>})},

      "google-fonts" =>
        %{"pattern" => ["fonts.googleapis.com"],
        "description" => gettext(~s{The site loads fonts from Google Fonts. While these are hosted on resource-specific domains and no cookies are sent, Google <em>could</em> possibly cross-reference the data (IP and browser fingerprint) with other Google services to identify visitors. Do they? Their own <a href="https://developers.google.com/fonts/faq?hl=en#what_does_using_the_google_fonts_api_mean_for_the_privacy_of_my_users">FAQ</a> is vague: <em>"We do log records of the CSS and the font file requests, and access to this data is on a need-to-know basis and kept secure."</em> What "need-to-know basis" means is not explained.}),
        "alternative" => gettext(~s{Fonts can easily be self-hosted. The tool <a href="https://google-webfonts-helper.herokuapp.com/fonts">google-webfonts-helper</a> lets you select one or more fonts, generates the proper CSS and prepares a zip file with the fonts. For a command-line alternative, the shell script <a href="https://github.com/neverpanic/google-font-download">google-font-download</a> provides similar functionality.})},

      "piwik" =>
        %{"pattern" => ["piwik.php", "piwik.js"],
        "description" => gettext(~s{The site appears to use Piwik, but not self-hosted. This means visitors are exposed to a third party.}),
        "alternative" => gettext(~s{Install Piwik on your own server. It's easy to install and easy to upgrade.})}
    }
  end

  def headers_to_check do
    %{
      "Strict-Transport-Security" =>
        gettext(~s{HTTP Strict Transport Security is an excellent feature to support on your site and strengthens your implementation of TLS by getting the User Agent to enforce the use of HTTPS.}),
      "Content-Security-Policy" =>
        gettext(~s{Content Security Policy is an effective measure to protect your site from XSS attacks. By whitelisting sources of approved content, you can prevent the browser from loading malicious assets.}),
      "Public-Key-Pins" =>
        gettext(~s{HTTP Public Key Pinning protects your site from MiTM attacks using rogue X.509 certificates. By whitelisting only the identities that the browser should trust, your users are protected in the event a certificate authority is compromised.}),
      "X-Frame-Options" =>
        gettext(~s{X-Frame-Options tells the browser whether you want to allow your site to be framed or not. By preventing a browser from framing your site you can defend against attacks like clickjacking.}),
      "X-Xss-Protection" =>
        gettext(~s{X-XSS-Protection sets the configuration for the cross-site scripting filters built into most browsers. The best configuration is "X-XSS-Protection: 1; mode=block".}),
      "X-Content-Type-Options" =>
        gettext(~s{X-Content-Type-Options stops a browser from trying to MIME-sniff the content type and forces it to stick with the declared content-type. This helps to reduce the danger of drive-by downloads. The only valid value for this header is "X-Content-Type-Options: nosniff".})
    }
  end

  def get_site_meta(site) do
    csp_referrer = check_csp_referrer(site.data["headers"])
    meta_referrer = site.data["meta_referrer"]
    referrer_policy_in_use =  cond do
      meta_referrer && csp_referrer -> meta_referrer
      meta_referrer -> meta_referrer
      csp_referrer -> csp_referrer
      true -> nil
    end

    %{"services" => check_services(site.data["third_party_requests"]),
      "referrer_policy" => check_referrer_policy(referrer_policy_in_use),
      "meta_referrer" => meta_referrer,
      "csp_referrer" => csp_referrer,
      "host" => URI.parse(site.final_url).host,
      "reg_domain" => PublicSuffix.registrable_domain(URI.parse(site.final_url).host),
      "hsts" => site.data["headers"]["strict-transport-security"]
    }
  end

  def get_unique_hosts(data, field_name) do
    data
    |> Enum.reduce([], fn(%{^field_name => host}, acc) -> acc ++ [host] end)
    |> Enum.uniq
  end

  def check_csp_referrer(headers) do
    if Map.has_key?(headers, "content-security-policy") do
      case Regex.run(~r/\breferrer ([\w-]+)\b/, headers["content-security-policy"]) do
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

  def truncate(string, maximum) do
    case String.length(string) > maximum do
      true -> "#{String.slice(string, 0, maximum)}..."
      false -> string
    end
  end
end