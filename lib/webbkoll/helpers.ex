defmodule Webbkoll.Helpers do
  import WebbkollWeb.Gettext

  @countries (fn ->
                for lang <- Application.get_env(:webbkoll, :locales), into: %{} do
                  {lang, Application.app_dir(:webbkoll, "priv/#{lang}.json") |> File.read!() |> Jason.decode!()}
                end
              end).()

  def country_from_iso(locale, country_code) do
    case Map.fetch(@countries[locale], country_code) do
      :error -> nil
      {:ok, country} -> country
    end
  end

  def check_services(nil), do: []

  def check_services(requests) do
    urls = for {_host, value} <- requests, request <- value, do: request.url

    urls
    |> Enum.reduce([], &check_services/2)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp check_services(url, results) do
    for {k, v} <- services(), String.contains?(url, v["pattern"]), into: results do
      [k | results]
    end
  end

  def get_service(service, key) do
    if Map.has_key?(services(), service) do
      services()[service][key]
    end
  end

  # TODO: Would be nicer to have this in a JSON file, but then gettext
  # becomes complicated (?)
  defp services do
    %{
      "cdn" => %{
        "pattern" => [
          "code.jquery.com",
          "ajax.googleapis.com/ajax/libs",
          "ajax.aspnetcdn.com",
          "cdnjs.cloudflare.com",
          "maxcdn.bootstrapcdn.com"
        ],
        "description" => gettext(~s{The site is loading libraries from one or more CDN:s.}),
        "alternative" => gettext(~s{Self-host the files.})
      },
      "disqus" => %{
        "pattern" => ["disqus.com"],
        "description" => gettext(~s{The site is using the Disqus comment system.}),
        "alternative" => gettext(~s{Consider a self-hosted platform.})
      },
      "google-analytics" => %{
        "pattern" => ["google-analytics.com"],
        "description" =>
          gettext(
            ~s{The site is using Google Analytics. While this is a powerful tool, we think you should respect your users' privacy and not tell Google about them &mdash; at least not without your users' consent.}
          ),
        "alternative" =>
          gettext(
            ~s{<a href="https://matomo.org/">Matomo</a> (formerly Piwik) is an excellent alternative. It's free software (PHP & MySQL) and you run it on your own server, meaning <em>you</em> are in control of the data. It offers various privacy settings and, unlike Google Analytics, it can be used without cookies. <em>(While analytics might be considered essential by some websites, another alternative is <em>don't track people just because you can</em>. Visitors do not, in fact, have an implicit obligation to help you optimize things.)</em>}
          )
      },
      "google-fonts" => %{
        "pattern" => ["fonts.googleapis.com"],
        "description" =>
          gettext(
            ~s{The site loads fonts from Google Fonts. While these are hosted on resource-specific domains and no cookies are sent, Google <em>could</em> possibly cross-reference the data (IP and browser fingerprint) with other Google services to identify visitors. Do they? Their own <a href="https://developers.google.com/fonts/faq?hl=en#what_does_using_the_google_fonts_api_mean_for_the_privacy_of_my_users">FAQ</a> is vague: <em>"We do log records of the CSS and the font file requests, and access to this data is on a need-to-know basis and kept secure."</em> What "need-to-know basis" means is not explained.}
          ),
        "alternative" =>
          gettext(
            ~s{Fonts can easily be self-hosted. The tool <a href="https://google-webfonts-helper.herokuapp.com/fonts">google-webfonts-helper</a> lets you select one or more fonts, generates the proper CSS and prepares a zip file with the fonts. For a command-line alternative, the shell script <a href="https://github.com/neverpanic/google-font-download">google-font-download</a> provides similar functionality.}
          )
      },
      "piwik" => %{
        "pattern" => ["piwik.php", "piwik.js"],
        "description" =>
          gettext(
            ~s{The site appears to use Matomo/Piwik, but not self-hosted. This means visitors are exposed to a third party.}
          ),
        "alternative" =>
          gettext(
            ~s{Install <a href="https://matomo.org/">Matomo</a> (formerly Piwik) on your own server. It's easy to install and easy to upgrade.}
          )
      }
    }
  end

  def headers_to_check do
    %{
      "X-Frame-Options" =>
        gettext(
          ~s{<a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options">X-Frame-Options</a> tells the browser whether you want to allow your site to be framed or not. By preventing a browser from framing your site you can defend against attacks like clickjacking.}
        ),
      "X-Xss-Protection" =>
        gettext(
          ~s{<a href="http://stackoverflow.com/questions/9090577/what-is-the-http-header-x-xss-protection">X-XSS-Protection</a> sets the configuration for the cross-site scripting filters built into most browsers. The best configuration is "X-XSS-Protection: 1; mode=block".}
        ),
      "X-Content-Type-Options" =>
        gettext(
          ~s{<a href="http://stackoverflow.com/questions/18337630/what-is-x-content-type-options-nosniff">X-Content-Type-Options</a> stops a browser from trying to MIME-sniff the content type and forces it to stick with the declared content-type. This helps to reduce the danger of drive-by downloads. The only valid value for this header is "X-Content-Type-Options: nosniff".}
        )
    }
  end

  def get_unique_hosts(data, field_name) do
    data
    |> Enum.map(&(&1[field_name]))
    |> Enum.uniq()
  end

  def truncate(string, maximum) do
    case String.length(string) > maximum do
      true -> "#{String.slice(string, 0, maximum)}..."
      false -> string
    end
  end

  def idna_from_punycode(host) do
    host
    |> String.to_charlist()
    |> :idna.from_ascii()
    |> List.to_string()
  end

  def get_headers(url) when is_binary(url) do
    url
    |> HTTPoison.head()
    |> handle_get_headers()
  end
  def handle_get_headers({:ok, response}) do
    {:ok, Enum.map(response.headers, fn {k, v} -> {String.downcase(k), v} end)}
  end
  def handle_get_headers({:error, reason}) do
    {:error, reason}
  end

  def find_header(url, header) do
    url
    |> get_headers()
    |> handle_find_header(header)
  end
  defp handle_find_header({:error, reason}, _), do: {:error, reason}
  defp handle_find_header({:ok, headers}, header) do
    headers
    |> Enum.find(fn {k, _} -> k == header end)
    |> case do
      nil -> {:ok, nil}
      {_, v} -> {:ok, v}
    end
  end

  def get_registerable_domain(host) do
    case PublicSuffix.matches_explicit_rule?(host) do
      true -> PublicSuffix.registrable_domain(host)
      false -> host
    end
  end
end
