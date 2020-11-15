defmodule WebbkollWeb.Router do
  use WebbkollWeb, :router

  @default_locale Application.get_env(:webbkoll, :default_locale)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :webbkoll do
    plug(WebbkollWeb.Plugs.MoreSecureHeaders)
    plug(WebbkollWeb.Plugs.Locale, @default_locale)
  end

  pipeline :api do
    plug(:accepts, ["json", "html"])
  end

  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/api", WebbkollWeb do
      pipe_through(:api)

      post("/check", API.SiteController, :create)
      get("/check", API.SiteController, :show)
    end

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard"
    end
  end

  scope "/", WebbkollWeb do
    pipe_through([:browser, :webbkoll])

    get("/", PageController, :index)
  end

  scope "/:locale", WebbkollWeb do
    pipe_through([:browser, :webbkoll])

    get("/check", SiteController, :create)
    get("/status", SiteController, :status)
    get("/results", SiteController, :results)

    get("/news", PageController, :news)
    get("/faq", PageController, :faq)
    get("/about", PageController, :about)
    get("/donate", PageController, :donate)

    get("/", PageController, :index)
  end
end
