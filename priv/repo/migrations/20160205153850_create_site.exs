defmodule Webbkoll.Repo.Migrations.CreateSite do
  use Ecto.Migration

  def change do

    create table(:sites, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :input_url, :string, size: 2083
      add :final_url, :string, size: 2083
      add :status, :string
      add :status_message, :string
      add :data, :map

      timestamps()
    end

  end
end
