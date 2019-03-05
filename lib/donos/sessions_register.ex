defmodule Donos.SessionsRegister do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def get(user_id) do
    GenServer.call(__MODULE__, {:get, user_id})
  end

  def register(user_id, session) do
    GenServer.cast(__MODULE__, {:register, user_id, session})
  end

  def unregister(user_id) do
    GenServer.cast(__MODULE__, {:unregister, user_id})
  end

  @impl GenServer
  def init(:none) do
    {:ok, Map.new()}
  end

  @impl GenServer
  def handle_call({:get, user_id}, _, sessions) do
    {:reply, Map.fetch(sessions, user_id), sessions}
  end

  @impl GenServer
  def handle_cast({:register, user_id, session}, sessions) do
    {:noreply, Map.put(sessions, user_id, session)}
  end

  @impl GenServer
  def handle_cast({:unregister, user_id}, sessions) do
    {:noreply, Map.delete(sessions, user_id)}
  end
end
