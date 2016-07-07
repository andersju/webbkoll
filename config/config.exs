# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :webbkoll,
  ecto_repos: [Webbkoll.Repo]

# Configures the endpoint
config :webbkoll, Webbkoll.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Yk9QpNTp3jg15sA4KFDjBq4hgfp0eYV0o1bYO6Hxf0BUV5deh4HkwMks/Z541bCR",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Webbkoll.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine

config :quantum, cron: [
    "@daily":       {Webbkoll.CronJobs, :remove_old_records},
    "@hourly":      {Webbkoll.CronJobs, :remove_stuck_records}
]
