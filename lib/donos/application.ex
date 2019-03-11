defmodule Donos.Application do
  use Application

  def start(_type, _args) do
    children = [
      Donos.Store,
      Donos.NamesRegister,
      Donos.SessionsRegister,
      Donos.Bot
    ]

    options = [
      strategy: :one_for_one,
      name: Donos.Supervisor
    ]

    Supervisor.start_link(children, options)
  end
end
