defmodule Donos.Repo do
  use Ecto.Repo,
    otp_app: :donos,
    adapter: Ecto.Adapters.Postgres
end
