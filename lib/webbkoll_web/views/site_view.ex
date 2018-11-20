defmodule WebbkollWeb.SiteView do
  use WebbkollWeb, :view

  def format_timestamp(nil) do
    "session"
  end

  def format_timestamp(time) do
    time
    |> Kernel.round()
    |> DateTime.from_unix!()
    |> DateTime.to_string()
  end

  def format_site_time(timestamp) do
    timestamp
    |> DateTime.from_unix!(:microsecond)
    |> Timex.format!("%Y-%m-%d %H:%M:%S %Z", :strftime)
  end

  def get_referrer_string(status) do
    case status do
      "success" -> gettext("Referrers not leaked")
      "warning" -> gettext("Referrers partially leaked")
      "alert" -> gettext("Referrers leaked")
      _ -> gettext("Referrers are (probably) leaked")
    end
  end

  def icon(:pass), do: content_tag(:i, "", class: "fas fa-check fa-fw success")
  def icon(:pass2), do: content_tag(:i, "", class: "fas fa-check-square fa-fw success")
  def icon(:fail), do: content_tag(:i, "", class: "fas fa-times fa-fw alert")
  def icon(:warn), do: content_tag(:i, "", class: "fas fa-exclamation-circle fa-fw warning")
  def icon(:optional), do: content_tag(:i, "", class: "fas fa-minus fa-fw")
  def icon(:info), do: content_tag(:i, "", class: "fas fa-info-circle fa-fw")
  def icon(:unknown), do: content_tag(:i, "", class: "fas fa-question-circle fa-fw")

  def csp_policy(policy, value) do
    pass =
      if policy in [:insecureBaseUri, :insecureFormAction, :insecureSchemeActive, :insecureSchemePassive, :unsafeEval, :unsafeInline, :unsafeInlineStyle, :unsafeObjects], do: !value, else: value

    {test, info} =
      case policy do
        :antiClickjacking ->
          {gettext("Clickjacking protection, using <code>frame-ancestors</code>"),
          gettext("The use of CSP's <code>frame-ancestors</code> directive offers fine-grained control over who can frame your site.")}
        :defaultNone ->
          {gettext("Deny by default, using <code>default-src 'none'</code>"),
          gettext("Denying by default using <code>default-src 'none'</code> can ensure that your Content Security Policy doesn't allow the loading of resources you didn't intend to allow.")}
        :insecureBaseUri ->
          {gettext("Restricts use of the <code>&lt;base&gt;</code> tag by using <code>base-uri 'none'</code>, <code>base-uri 'self'</code>, or specific origins"),
          gettext("The <code>base</code> tag can be used to trick your site into loading scripts from untrusted origins.")}
        :insecureFormAction ->
          {gettext("Restricts where <code>&lt;form&gt;</code> contents may be submitted by using <code>form-action 'none'</code>, <code>form-action 'self'</code>, or specific URIs"),
          gettext("Malicious JavaScript or content injection could modify where sensitive form data is submitted to or create additional forms for data exfiltration.")}
        :insecureSchemeActive ->
          {gettext("Blocks loading of active content over HTTP or FTP"),
          gettext("Loading JavaScript or plugins can allow a man-in-the-middle to execute arbitrary code or your website. Restricting your policy and changing links to HTTPS can help prevent this.")}
        :insecureSchemePassive ->
          {gettext("Blocks loading of passive content over HTTP or FTP"),
          gettext("This site's Content Security Policy allows the loading of passive content such as images or videos over insecure protocols such as HTTP or FTP. Consider changing them to load them over HTTPS.")}
        :strictDynamic ->
          {gettext("Uses CSP3's <code>'strict-dynamic'</code> directive to allow dynamic script loading (optional)"),
          gettext("<code>'strict-dynamic'</code> lets you use a JavaScript shim loader to load all your site's JavaScript dynamically, without having to track <code>script-src</code> origins.")}
        :unsafeEval ->
          {gettext("Blocks execution of JavaScript's <code>eval()</code> function by not allowing <code>'unsafe-eval'</code> inside <code>script-src</code>"),
          gettext("Blocking the use of JavaScript's <code>eval()</code> function can help prevent the execution of untrusted code.")}
        :unsafeInline ->
          {gettext("Blocks execution of inline JavaScript by not allowing <code>'unsafe-inline'</code> inside <code>script-src</code>"),
          gettext("Blocking the execution of inline JavaScript provides CSP's strongest protection against cross-site scripting attacks. Moving JavaScript to external files can also help make your site more maintainable.")}
        :unsafeInlineStyle ->
          {gettext("Blocks inline styles by not allowing <code>'unsafe-inline'</code> inside <code>style-src</code>"),
          gettext("Blocking inline styles can help prevent attackers from modifying the contents or appearance of your page. Moving styles to external stylesheets can also help make your site more maintainable.")}
        :unsafeObjects ->
          {gettext("Blocks execution of plug-ins, using <code>object-src</code> restrictions"),
          gettext("Blocking the execution of plug-ins via <code>object-src 'none'</code> or as inherited from <code>default-src</code> can prevent attackers from loading Flash or Java in the context of your page.")}
        _ -> {"", ""}
      end

    case policy do
      :strictDynamic -> {test, pass, info, true}
      _ -> {test, pass, info, false}
    end
  end
end
