# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :webbkoll,
  locales: ~w(en sv),
  default_locale: "en"

# Configures the endpoint
config :webbkoll, WebbkollWeb.Endpoint,
  url: [host: "localhost"],
  # secret_key_base is not actually used for anything at the moment, as Webbkoll doesn't
  # use cookies at all.
  secret_key_base: "Yk9QpNTp3jg15sA4KFDjBq4hgfp0eYV0o1bYO6Hxf0BUV5deh4HkwMks/Z541bCR",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Webbkoll.PubSub, adapter: Phoenix.PubSub.PG2],
  server: true

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :error

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine

config :webbkoll, Webbkoll.Scheduler,
  jobs: [
    {"@reboot", {Webbkoll.CronJobs, :download_geoip_if_not_exists, []}},
    {"@weekly", {Webbkoll.CronJobs, :update_geoip, []}},
    {"* * * * *", {Webbkoll.CronJobs, :find_and_remove_stuck_records, []}},
  ]

config :geolix,
  databases: [
    %{
      id: :country,
      adapter: Geolix.Adapter.MMDB2,
      source: "priv/GeoLite2-Country.mmdb.gz"
    }
  ]
