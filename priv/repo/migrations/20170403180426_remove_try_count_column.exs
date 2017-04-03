defmodule Webbkoll.Repo.Migrations.RemoveTryCountColumn do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      remove :try_count
    end
  end
end
