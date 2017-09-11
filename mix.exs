defmodule Webbkoll.Mixfile do
  use Mix.Project

  def project do
    [app: :webbkoll,
     version: "0.0.1",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Webbkoll.Application, []},
     applications: [:phoenix, :phoenix_pubsub, :phoenix_html, :cowboy, :logger, :gettext,
                    :httpoison, :tzdata, :ex_rated, :quantum, :timex, :geolix, :con_cache],
     included_applications: [:ex2ms, :exq, :floki, :phoenix_slime, :public_suffix]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.3.0"},
     {:phoenix_pubsub, "~> 1.0"},
     {:phoenix_html, "~> 2.10"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:gettext, "~> 0.11"},
     {:cowboy, "~> 1.1"},
     {:httpoison, "~> 0.13"},
     {:floki, "~> 0.8"},
     {:exq, "~> 0.9"},
     {:ex_rated, "~> 1.2"},
     {:quantum, ">= 2.0.0"},
     {:ex_machina, "~> 2.0", only: :test},
     {:public_suffix, "~> 0.4"},
     {:phoenix_slime, "~> 0.8"},
     {:timex, "~> 3.0"},
     {:hackney, "~> 1.8"},
     {:geolix, "~> 0.13"},
     {:idna, "~> 5.0", override: true},
     {:con_cache, "~> 0.12.1"},
     {:uuid, "~> 1.1"}]
  end

  # Aliases are shortcut or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    #["test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
