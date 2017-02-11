defmodule Webbkoll.Site do
  use Webbkoll.Web, :model

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "sites" do
    field :input_url, :string
    field :final_url, :string
    field :status, :string
    field :status_message, :string
    field :data, :map
    field :try_count, :integer

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:input_url, :final_url, :status, :status_message, :data, :try_count])
    |> validate_required([:input_url])
  end
end
