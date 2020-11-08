defmodule Webbkoll.Mixfile do
  use Mix.Project

  def project do
    [
      app: :webbkoll,
      version: "0.0.1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Webbkoll.Application, []},
      included_applications: [:logger, :runtime_tools, :inets, :tzdata]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.3 or ~> 0.2.9"},
      {:gettext, "~> 0.11"},
      {:plug_cowboy, "~> 2.1"},
      {:plug, "~> 1.7"},
      {:httpoison, "~> 1.0"},
      {:floki, "~> 0.8"},
      {:ex_rated, "~> 2.0"},
      {:quantum, "~> 3.0"},
      {:ex_machina, "~> 2.0", only: :test},
      {:public_suffix, git: "https://github.com/andersju/publicsuffix-elixir.git", ref: "8937242"},
      {:timex, "~> 3.0"},
      {:hackney, "~> 1.8"},
      {:geolix_adapter_mmdb2, "~> 0.6.0"},
      {:idna, "~> 6.0"},
      {:con_cache, "~> 0.13"},
      {:uuid, "~> 1.1"},
      {:jumbo, "~> 1.0"},
      {:download, "~> 0.0.4"},
      {:stream_gzip, "~> 0.4.1"},
      {:jason, "~> 1.0"},
      {:valid_url, "~> 0.1.2"}
    ]
  end
end
