defmodule Webbkoll.Application do
  use Application

  @max_attempts Application.get_env(:webbkoll, :max_attempts)
  @backends Application.get_env(:webbkoll, :backends)

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: Webbkoll.PubSub},
      # Start the endpoint when the application starts
      WebbkollWeb.Endpoint,
      # Add the Quantum supervisor
      Webbkoll.Scheduler,
      # Add the ConCache ETS key/value store
      {ConCache,
       [
         name: :site_cache,
         ttl_check_interval: :timer.seconds(60),
         global_ttl: :timer.seconds(86_400)
       ]},
    ]

    # Workaround to make Geolix play nicer with Distillery
    [%{adapter: adapter, id: id, source: source}] = Application.get_env(:geolix, :databases)

    Geolix.load_database(%{
      adapter: adapter,
      id: id,
      source: Application.app_dir(:webbkoll, source)
    })

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Webbkoll.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    # Start job queue and workers
    Enum.each(@backends, fn {queue, settings} ->
      :ok =
        Honeydew.start_queue(queue,
          queue: Honeydew.Queue.ErlangQueue,
          failure_mode: {
            Honeydew.FailureMode.Retry,
            [times: @max_attempts - 1, base: 2]
          }
        )

      :ok = Honeydew.start_workers(queue, Webbkoll.Worker, num: settings.concurrency)
    end)

    {:ok, supervisor}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    WebbkollWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
