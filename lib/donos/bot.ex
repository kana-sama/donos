defmodule Donos.Bot do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :none, name: __MODULE__)
  end

  @impl Supervisor
  def init(:none) do
    children = [
      Donos.Bot.Logic,
      Donos.Bot.Loop
    ]

    options = [
      strategy: :one_for_one,
      name: __MODULE__
    ]

    Supervisor.init(children, options)
  end
end
