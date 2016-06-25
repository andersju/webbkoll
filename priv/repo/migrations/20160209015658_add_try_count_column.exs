defmodule Webbkoll.Repo.Migrations.AddRetryCountColumn do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :try_count, :integer, default: 0
    end
  end
end
