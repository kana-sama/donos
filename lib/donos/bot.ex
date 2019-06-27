defmodule Donos.Bot do
  use Supervisor

  alias Donos.Bot.{Loop, Logic}

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :none, name: __MODULE__)
  end

  @impl Supervisor
  def init(:none) do
    children = [
      Loop,
      Logic
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
