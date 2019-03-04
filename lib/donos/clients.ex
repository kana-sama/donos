defmodule Donos.Clients do
  use GenServer

  alias Donos.Client

  defmodule State do
    defstruct users: MapSet.new(), connected: Map.new()
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def users do
    GenServer.call(__MODULE__, :users)
  end

  def get_or_register(user_id) do
    GenServer.call(__MODULE__, {:get_or_register, user_id})
  end

  def unregister(user_id) do
    GenServer.cast(__MODULE__, {:unregister, user_id})
  end

  @impl GenServer
  def init(:none) do
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(:users, _, state) do
    {:reply, state.users, state}
  end

  @impl GenServer
  def handle_call({:get_or_register, user_id}, _, state) do
    case Map.fetch(state.connected, user_id) do
      {:ok, client} ->
        {:reply, client, state}

      :error ->
        {:ok, client} = Client.start(user_id)
        connected = Map.put(state.connected, user_id, client)
        users = MapSet.put(state.users, user_id)
        state = %State{users: users, connected: connected}
        {:reply, client, state}
    end
  end

  @impl GenServer
  def handle_cast({:unregister, user_id}, state) do
    {:noreply, %{state | connected: Map.delete(state.connected, user_id)}}
  end
end
