defmodule Donos.User do
  use Ecto.Schema

  schema "users" do
    field(:username, :string)
    field(:first_name, :string)
    field(:last_name, :string)

    timestamps()
  end

  def changeset(user, params \\ %{}) do
    user
    |> Ecto.Changeset.cast(params, [:username, :first_name, :last_name])
    |> Ecto.Changeset.validate_required([:first_name])
  end
end
