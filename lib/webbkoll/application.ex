defmodule Webbkoll.Application do
  use Application

  @max_attempts Application.get_env(:webbkoll, :max_attempts)
  @backends Application.get_env(:webbkoll, :backends)

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    jumbo_queues =
      Enum.map(@backends, fn({queue, v}) ->
        {queue,
         %Jumbo.QueueOptions{concurrency: v.concurrency, max_failure_count: @max_attempts, logger_tag: v.logger_tag}}
      end)

    children = [
      # Start the endpoint when the application starts
      supervisor(WebbkollWeb.Endpoint, []),
      # Add the Quantum supervisor
      worker(Webbkoll.Scheduler, []),
      # Add the ConCache ETS key/value store
      supervisor(ConCache, [[ttl_check: :timer.seconds(60), ttl: :timer.seconds(604800)], [name: :site_cache]]),
      # Add the Jumbo job queue supervisor
      supervisor(Jumbo.QueueSupervisor, [jumbo_queues, [name: Webbkoll.QueueSupervisor]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Webbkoll.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    WebbkollWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
