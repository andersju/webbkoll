use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :webbkoll, WebbkollWeb.Endpoint,
  http: [port: 4001],
  server: false,
  debug_errors: false

# Print only warnings and errors during test
config :logger, level: :warn

config :webbkoll,
  backends: [
    {Webbkoll.Queue.Q1, %{concurrency: 5, logger_tag: "queue 1", url: "http://localhost:8100/"}},
  ],
  max_attempts: 2,
  locales: ~w(en sv),
  default_locale: "sv",
  # validate_urls: If true, only check URLs with a valid domain name
  # (i.e. ones with a TLD in the Public Suffix List),
  # and only the standard HTTP/HTTPS ports.
  validate_urls: true,
  # rate_limit_client: An IP address can make <limit> new site checks
  # during <scale> milliseconds.
  # rate_limit_host: The tool will query a specific host no more than
  # <limit> times during <scale> milliseconds.
  # See https://github.com/grempe/ex_rated
  rate_limit_client: %{"scale" => 60_000, "limit" => 20},
  rate_limit_host: %{"scale" => 60_000, "limit" => 5}