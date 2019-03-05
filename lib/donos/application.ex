defmodule Donos.Application do
  use Application

  def show_own_messages?() do
    Application.get_env(:donos, :show_own_messages?)
  end

  def start(_type, _args) do
    children = [
      Donos.Store,
      Donos.Chat,
      Donos.SessionsRegister,
      Donos.TelegramAPI
    ]

    opts = [
      strategy: :one_for_one,
      name: Donos.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
