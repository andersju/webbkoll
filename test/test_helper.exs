{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start

Mix.Task.run "ecto.create", ~w(-r Webbkoll.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Webbkoll.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(Webbkoll.Repo)

