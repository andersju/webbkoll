import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :webbkoll, WebbkollWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "IvzBctBrLEScfiglXkTgxhEA8+/A6Eyyc4xYhzgAepLUnv8L7gbL7WK4cU4gx5uJ",
  watchers: []

# Watch static and templates for browser reloading.
config :webbkoll, WebbkollWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/webbkoll_web/(live|views)/.*(ex)$},
      ~r{lib/webbkoll_web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", level: :warn

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
