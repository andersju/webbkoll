defmodule WebbkollWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :webbkoll

  # socket "/socket", WebbkollWeb.UserSocket, 
  #  websocket: true, # or list of options
  #  longpoll: false

  plug RemoteIp

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :webbkoll,
    gzip: false,
    only: ~w(css flags fonts images js favicon.ico robots.txt .well-known)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger"
    #cookie_key: "request_logger"
  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session, store: :cookie, key: "_webbkoll_key", signing_salt: "4ZOjrKOO")

  plug(WebbkollWeb.Router)

  socket "/live", Phoenix.LiveView.Socket
end
