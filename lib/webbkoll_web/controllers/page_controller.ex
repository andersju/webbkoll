defmodule WebbkollWeb.PageController do
  use WebbkollWeb, :controller

  @check_host_only Application.compile_env(:webbkoll, :check_host_only)

  def index(conn, _params) do
    render(
      conn,
      "index.html",
      locale: conn.assigns.locale,
      page_title: gettext("Analyze"),
      page_description:
        gettext(
          "This tool helps you check what data-protecting measures a site has taken to help you exercise control over your privacy."
        ),
      check_host_only: @check_host_only
    )
  end

  def news(conn, _params) do
    render(
      conn,
      "news.html",
      locale: conn.assigns.locale,
      page_title: gettext("News"),
      page_description: gettext("Recent changes on Webbkoll.")
    )
  end

  def faq(conn, _params) do
    render(
      conn,
      "faq.html",
      locale: conn.assigns.locale,
      page_title: gettext("FAQ"),
      page_description:
        gettext(
          "The what and why of data protection and the principles of the EU general data protection regulation."
        )
    )
  end

  def about(conn, _params) do
    render(
      conn,
      "about.html",
      locale: conn.assigns.locale,
      page_title: gettext("About"),
      page_description: gettext("How Webbkoll works, who made it, and alternative services.")
    )
  end

  def donate(conn, _params) do
    render(
      conn,
      "donate.html",
      locale: conn.assigns.locale,
      page_title: gettext("Donate"),
      page_description: gettext("How you can support our work.")
    )
  end
end
