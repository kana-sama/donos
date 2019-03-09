defmodule Donos.Bot do
  use Supervisor

  alias Donos.Bot.{Loop, Logic}

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def system_message(user_id, message) do
    Logic.send_message(user_id, {:system, message})
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
