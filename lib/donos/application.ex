defmodule Donos.Application do
  use Application

  alias Donos.{Clients, TelegramAPI}

  def start(_type, _args) do
    children = [
      Clients,
      TelegramAPI
    ]

    opts = [strategy: :one_for_one, name: Donos.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
