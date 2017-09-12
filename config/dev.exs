use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :webbkoll, WebbkollWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../assets", __DIR__)]]

# Watch static and templates for browser reloading.
config :webbkoll, WebbkollWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/webbkoll_web/views/.*(ex)$},
      ~r{lib/webbkoll_web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20

config :webbkoll,
  backends: [
    {Webbkoll.Queue.Q1, %{concurrency: 5, logger_tag: "queue 1", url: "http://localhost:8100/"}},
  ],
  max_attempts: 2,
  locales: ~w(en sv),
  default_locale: "en",
  # validate_urls: If true, only check URLs with a valid domain name
  # (i.e. ones with a TLD in the Public Suffix List),
  # and only the standard HTTP/HTTPS ports.
  validate_urls: false,
  # rate_limit_client: An IP address can make <limit> new site checks
  # during <scale> milliseconds.
  # rate_limit_host: The tool will query a specific host no more than
  # <limit> times during <scale> milliseconds.
  # See https://github.com/grempe/ex_rated
  rate_limit_client: %{"scale" => 60_000, "limit" => 20},
  rate_limit_host: %{"scale" => 60_000, "limit" => 5}
