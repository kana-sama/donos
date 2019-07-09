defmodule Donos.Application do
  use Application

  def start(_type, _args) do
    children = [
      Donos.Repo
    ]

    opts = [
      strategy: :one_for_one,
      name: Donos.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
