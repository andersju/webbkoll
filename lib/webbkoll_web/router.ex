defmodule WebbkollWeb.Router do
  use WebbkollWeb, :router
  @default_locale Application.get_env(:webbkoll, :default_locale)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Webbkoll.MoreSecureHeaders)
    plug(Webbkoll.Locale, @default_locale)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", WebbkollWeb do
    pipe_through(:browser)

    get("/", SiteController, :index)
  end

  scope "/:locale", WebbkollWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/about", SiteController, :about)
    get("/tech", SiteController, :tech)
    get("/donate", SiteController, :donate)
    get("/check", SiteController, :check)
    get("/status", SiteController, :status)
    get("/results", SiteController, :results)

    get("/", SiteController, :indexi18n)
  end

  # Other scopes may use custom stacks.
  # scope "/api", Webbkoll do
  #   pipe_through :api
  # end
end
