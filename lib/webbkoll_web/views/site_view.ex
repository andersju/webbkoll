defmodule WebbkollWeb.SiteView do
  use WebbkollWeb, :view

  def format_timestamp(nil) do
    "session"
  end

  def format_timestamp(time) do
    time
    |> min(253_402_300_799)
    |> round()
    |> DateTime.from_unix()
    |> case do
      {:ok, datetime} -> DateTime.to_string(datetime)
      {:error, _} -> "invalid"
    end
  end

  def format_site_time(timestamp) do
    case DateTime.from_unix(timestamp, :microsecond) do
      {:ok, datetime} -> Timex.format!(datetime, "%Y-%m-%d %H:%M:%S %Z", :strftime)
      {:error, _} -> "invalid"
    end
  end

  def get_referrer_string(status) do
    case status do
      "success" -> gettext("Referrers not leaked")
      "warning" -> gettext("Referrers partially leaked")
      "alert" -> gettext("Referrers leaked")
      _ -> gettext("Referrers are (probably) leaked")
    end
  end

  def anchor_link(id) do
    assigns = %{} # can't use ~H without assigns defined
    ~H|<a href={"##{id}"} aria-label="Anchor" class="anchor-link"><i class="icon-link"></i></a>|
  end

  def icon(:pass), do: content_tag(:i, "", class: "icon-check success")
  def icon(:pass2), do: content_tag(:i, "", class: "icon-check-square success")
  def icon(:fail), do: content_tag(:i, "", class: "icon-times alert")
  def icon(:warn), do: content_tag(:i, "", class: "icon-notification warning")
  def icon(:warn_strong), do: content_tag(:i, "", class: "icon-notification alert")
  def icon(:optional), do: content_tag(:i, "", class: "icon-minus")
  def icon(:info), do: content_tag(:i, "", class: "icon-info")
  def icon(:unknown), do: content_tag(:i, "", class: "icon-question-circle")
  def icon(:law), do: content_tag(:i, "", class: "icon-gavel")

  def result_text(result) do
    case result do
      "csp-implemented-with-no-unsafe-default-src-none" ->
        gettext(
          "Content Security Policy (CSP) implemented with <code>default-src 'none'</code> and no <code>'unsafe'</code>"
        )

      "csp-implemented-with-no-unsafe" ->
        gettext(
          "Content Security Policy (CSP) implemented without <code>'unsafe-inline'</code> or <code>'unsafe-eval'</code>"
        )

      "csp-implemented-with-unsafe-inline-in-style-src-only" ->
        gettext(
          "Content Security Policy (CSP) implemented with unsafe sources inside <code>style-src</code>. This includes <code>'unsafe-inline'</code>, <code>data:</code> or overly broad sources such as <code>https:</code>."
        )

      "csp-implemented-with-insecure-scheme-in-passive-content-only" ->
        gettext(
          "Content Security Policy (CSP) implemented, but secure site allows images or media to be loaded over HTTP"
        )

      "csp-implemented-with-unsafe-eval" ->
        gettext(
          "Content Security Policy (CSP) implemented, but allows <code>'unsafe-eval'</code>"
        )

      "csp-implemented-with-unsafe-inline" ->
        gettext(
          "Content Security Policy (CSP) implemented unsafely. This includes <code>'unsafe-inline'</code> or <code>data:</code> inside <code>script-src</code>, overly broad sources such as <code>https:</code> inside <code>object-src</code> or <code>script-src</code>, or not restricting the sources for <code>object-src</code> or <code>script-src</code>."
        )

      "csp-implemented-with-insecure-scheme" ->
        gettext(
          "Content Security Policy (CSP) implemented, but secure site allows resources to be loaded over HTTP"
        )

      "csp-header-invalid" ->
        gettext("Content Security Policy (CSP) header cannot be parsed successfully.")

      "csp-not-implemented" ->
        gettext("Content Security Policy (CSP) header not implemented.")

      "x-content-type-options-nosniff" ->
        gettext("X-Content-Type-Options header set to \"nosniff\"")

      "x-content-type-options-not-implemented" ->
        gettext("X-Content-Type-Options header not implemented")

      "x-content-type-options-header-invalid" ->
        gettext("X-Content-Type-Options header cannot be recognized")

      "x-frame-options-implemented-via-csp" ->
        gettext("X-Frame-Options (XFO) implemented via the CSP frame-ancestors directive")

      "x-frame-options-sameorigin-or-deny" ->
        gettext("X-Frame-Options (XFO) header set to SAMEORIGIN or DENY")

      "x-frame-options-allow-from-origin" ->
        gettext("X-Frame-Options (XFO) header uses ALLOW-FROM uri directive")

      "x-frame-options-not-implemented" ->
        gettext("X-Frame-Options (XFO) header not implemented")

      "x-frame-options-header-invalid" ->
        gettext("X-Frame-Options (XFO) header cannot be recognized")

      "x-xss-protection-enabled-mode-block" ->
        gettext("X-XSS-Protection header set to \"1; mode=block\"")

      "x-xss-protection-enabled" ->
        gettext("X-XSS-Protection header set to \"1\"")

      "x-xss-protection-not-needed-due-to-csp" ->
        gettext(
          "X-XSS-Protection header not needed due to strong Content Security Policy (CSP) header"
        )

      "x-xss-protection-disabled" ->
        gettext("X-XSS-Protection header set to \"0\" (disabled)")

      "x-xss-protection-not-implemented" ->
        gettext("X-XSS-Protection header not implemented")

      "x-xss-protection-header-invalid" ->
        gettext("X-XSS-Protection header cannot be recognized")

      _ ->
        ""
    end
  end

  def csp_policy(policy, value) do
    pass =
      if policy in [
           :insecureBaseUri,
           :insecureFormAction,
           :insecureSchemeActive,
           :insecureSchemePassive,
           :unsafeEval,
           :unsafeInline,
           :unsafeInlineStyle,
           :unsafeObjects
         ],
         do: !value,
         else: value

    {test, info} =
      case policy do
        :antiClickjacking ->
          {gettext("Clickjacking protection, using <code>frame-ancestors</code>"),
           gettext(
             "The use of CSP's <code>frame-ancestors</code> directive offers fine-grained control over who can frame your site."
           )}

        :defaultNone ->
          {gettext("Deny by default, using <code>default-src 'none'</code>"),
           gettext(
             "Denying by default using <code>default-src 'none'</code> can ensure that your Content Security Policy doesn't allow the loading of resources you didn't intend to allow."
           )}

        :insecureBaseUri ->
          {gettext(
             "Restricts use of the <code>&lt;base&gt;</code> tag by using <code>base-uri 'none'</code>, <code>base-uri 'self'</code>, or specific origins"
           ),
           gettext(
             "The <code>base</code> tag can be used to trick your site into loading scripts from untrusted origins."
           )}

        :insecureFormAction ->
          {gettext(
             "Restricts where <code>&lt;form&gt;</code> contents may be submitted by using <code>form-action 'none'</code>, <code>form-action 'self'</code>, or specific URIs"
           ),
           gettext(
             "Malicious JavaScript or content injection could modify where sensitive form data is submitted to or create additional forms for data exfiltration."
           )}

        :insecureSchemeActive ->
          {gettext("Blocks loading of active content over HTTP or FTP"),
           gettext(
             "Loading JavaScript or plugins can allow a man-in-the-middle to execute arbitrary code on your website. Restricting your policy and changing links to HTTPS can help prevent this."
           )}

        :insecureSchemePassive ->
          {gettext("Blocks loading of passive content over HTTP or FTP"),
           gettext(
             "This site's Content Security Policy allows the loading of passive content such as images or videos over insecure protocols such as HTTP or FTP. Consider changing them to load them over HTTPS."
           )}

        :strictDynamic ->
          {gettext(
             "Uses CSP3's <code>'strict-dynamic'</code> directive to allow dynamic script loading (optional)"
           ),
           gettext(
             "<code>'strict-dynamic'</code> lets you use a JavaScript shim loader to load all your site's JavaScript dynamically, without having to track <code>script-src</code> origins."
           )}

        :unsafeEval ->
          {gettext(
             "Blocks execution of JavaScript's <code>eval()</code> function by not allowing <code>'unsafe-eval'</code> inside <code>script-src</code>"
           ),
           gettext(
             "Blocking the use of JavaScript's <code>eval()</code> function can help prevent the execution of untrusted code."
           )}

        :unsafeInline ->
          {gettext(
             "Blocks execution of inline JavaScript by not allowing <code>'unsafe-inline'</code> inside <code>script-src</code>"
           ),
           gettext(
             "Blocking the execution of inline JavaScript provides CSP's strongest protection against cross-site scripting attacks. Moving JavaScript to external files can also help make your site more maintainable."
           )}

        :unsafeInlineStyle ->
          {gettext(
             "Blocks inline styles by not allowing <code>'unsafe-inline'</code> inside <code>style-src</code>"
           ),
           gettext(
             "Blocking inline styles can help prevent attackers from modifying the contents or appearance of your page. Moving styles to external stylesheets can also help make your site more maintainable."
           )}

        :unsafeObjects ->
          {gettext("Blocks execution of plug-ins, using <code>object-src</code> restrictions"),
           gettext(
             "Blocking the execution of plug-ins via <code>object-src 'none'</code> or as inherited from <code>default-src</code> can prevent attackers from loading Flash or Java in the context of your page."
           )}

        _ ->
          {"", ""}
      end

    case policy do
      :strictDynamic -> {test, pass, info, true}
      _ -> {test, pass, info, false}
    end
  end

  def gdpr([type, number]), do: gdpr_link(type, number)
  def gdpr([type, number, text]), do: gdpr_link(type, number, text)

  def gdpr(list) when is_list(list) do
    Enum.reduce(list, [], fn x, acc ->
      [gdpr(x) | acc]
    end)
    |> Enum.reverse()
    |> Enum.join(", ")
  end

  def gdpr_link(type, number, text \\ nil) do
    text = if text, do: text, else: number
    lang = Gettext.get_locale(WebbkollWeb.Gettext)

    case type do
      "art" ->
        safe_to_string(
          link(gettext("Art. ") <> text,
            to: "https://gdpr.dataskydd.net/#{lang}/art/#art#{number}"
          )
        )

      "rec" ->
        safe_to_string(
          link(gettext("Rec. ") <> text,
            to: "https://gdpr.dataskydd.net/#{lang}/rec/#rec#{number}"
          )
        )
    end
  end

  def http_status_text(status_code) when is_binary(status_code) do
    http_status_text(String.to_integer(status_code))
  end

  def http_status_text(status_code) do
    case status_code do
      100 -> "Continue"
      101 -> "Switching Protocols"
      102 -> "Processing"
      103 -> "Early Hints"
      200 -> "OK"
      201 -> "Created"
      202 -> "Accepted"
      203 -> "Non-Authoritative Information"
      204 -> "No Content"
      205 -> "Reset Content"
      206 -> "Partial Content"
      207 -> "Multi-Status"
      208 -> "Already Reported"
      226 -> "IM Used"
      300 -> "Multiple Choices"
      301 -> "Moved Permanently"
      302 -> "Found"
      303 -> "See Other"
      304 -> "Not Modified"
      305 -> "Use Proxy"
      306 -> "(Unused)"
      307 -> "Temporary Redirect"
      308 -> "Permanent Redirect"
      400 -> "Bad Request"
      401 -> "Unauthorized"
      402 -> "Payment Required"
      403 -> "Forbidden"
      404 -> "Not Found"
      405 -> "Method Not Allowed"
      406 -> "Not Acceptable"
      407 -> "Proxy Authentication Required"
      408 -> "Request Timeout"
      409 -> "Conflict"
      410 -> "Gone"
      411 -> "Length Required"
      412 -> "Precondition Failed"
      413 -> "Content Too Large"
      414 -> "URI Too Long"
      415 -> "Unsupported Media Type"
      416 -> "Range Not Satisfiable"
      417 -> "Expectation Failed"
      418 -> "(Unused)"
      421 -> "Misdirected Request"
      422 -> "Unprocessable Content"
      423 -> "Locked"
      424 -> "Failed Dependency"
      425 -> "Too Early"
      426 -> "Upgrade Required"
      428 -> "Precondition Required"
      429 -> "Too Many Requests"
      431 -> "Request Header Fields Too Large"
      451 -> "Unavailable For Legal Reasons"
      500 -> "Internal Server Error"
      501 -> "Not Implemented"
      502 -> "Bad Gateway"
      503 -> "Service Unavailable"
      504 -> "Gateway Timeout"
      505 -> "HTTP Version Not Supported"
      506 -> "Variant Also Negotiates"
      507 -> "Insufficient Storage"
      508 -> "Loop Detected"
      510 -> "Not Extended (OBSOLETED)"
      511 -> "Network Authentication Required"
      _ -> "[unassigned]"
    end
  end
end
