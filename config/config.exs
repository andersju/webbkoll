# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# General application configuration
config :webbkoll,
  locales: %{
    "en" => "English",
    "sv" => "Svenska",
    "de" => "Deutsch",
    "no" => "Norsk",
    "it" => "Italiano"
    # "fr" => "Français"
  },
  default_locale: "en",
  version: System.cmd("git", ["log", "-1", "--format=%h %ci"]) |> elem(0) |> String.trim()

# Configures the endpoint
config :webbkoll, WebbkollWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [accepts: ~w(html json)],
  pubsub_server: Webbkoll.PubSub,
  server: true

config :webbkoll,
  backends: [
    {Webbkoll.Queue.Q1, %{concurrency: 40, url: "http://localhost:8100/"}},
  ],
  max_attempts: 2,
  # validate_urls: If true, only check URLs with a valid domain name
  # (i.e. ones with a TLD in the Public Suffix List),
  # and only the standard HTTP/HTTPS ports.
  validate_urls: true,
  # check_host_only: If true, throw away path and query parameters from submitted URLs
  # before passing them on to the backend. (Only works if validate_urls is also true.)
  check_host_only: false,
  # rate_limit_client: An IP address can make <limit> new site checks during <scale> milliseconds.
  # rate_limit_host: The tool will query a specific host no more than <limit> times during <scale> milliseconds.
  # See https://github.com/grempe/ex_rated
  rate_limit_client: %{"scale" => 60_000, "limit" => 20},
  rate_limit_host: %{"scale" => 60_000, "limit" => 5}

config :webbkoll, Webbkoll.Scheduler,
  jobs: [
    {"* * * * *", {Webbkoll.CronJobs, :find_and_remove_stuck_records, []}}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :error

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :public_suffix, download_data_on_compile: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"