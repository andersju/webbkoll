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

  @required_fields ~w(input_url)
  @optional_fields ~w(final_url status status_message data try_count)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
