defmodule Donos.SessionsRegister do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> Map.new() end, name: __MODULE__)
  end

  def get(user_id) do
    Agent.get(__MODULE__, fn sessions ->
      Map.fetch(sessions, user_id)
    end)
  end

  def register(user_id, session) do
    Agent.update(__MODULE__, fn sessions ->
      Map.put(sessions, user_id, session)
    end)
  end

  def unregister(user_id) do
    Agent.update(__MODULE__, fn sessions ->
      Map.delete(sessions, user_id)
    end)
  end
end
