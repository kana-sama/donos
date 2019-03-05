defmodule Donos.SessionsRegister do
  use GenServer

  alias Donos.Session

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def get_or_start(user_id) do
    GenServer.call(__MODULE__, {:get_or_start, user_id})
  end

  def unregister(user_id) do
    GenServer.cast(__MODULE__, {:unregister, user_id})
  end

  @impl GenServer
  def init(:none) do
    {:ok, Map.new()}
  end

  @impl GenServer
  def handle_call({:get_or_start, user_id}, _, sessions) do
    case Map.fetch(sessions, user_id) do
      {:ok, session} ->
        {:reply, session, sessions}

      :error ->
        {:ok, session} = Session.start(user_id)
        sessions = Map.put(sessions, user_id, session)
        {:reply, session, sessions}
    end
  end

  @impl GenServer
  def handle_cast({:unregister, user_id}, sessions) do
    {:noreply, Map.delete(sessions, user_id)}
  end
end
