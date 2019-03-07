defmodule Donos.Store do
  use GenServer

  defmodule User do
    defstruct lifetime: Application.get_env(:donos, :session_lifetime)
  end

  defmodule Message do
    defstruct [:user_name, {:ids, Map.new()}]
  end

  defmodule State do
    defstruct users: Map.new(), messages: Map.new()
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def get_users() do
    GenServer.call(__MODULE__, :get_users)
  end

  def get_user(user_id) do
    GenServer.call(__MODULE__, {:get_user, user_id})
  end

  def get_messages(message_id) do
    GenServer.call(__MODULE__, {:get_messages, message_id})
  end

  def get_message_by_local(user_id, message_id) do
    GenServer.call(__MODULE__, {:get_message_by_local, user_id, message_id})
  end

  def put_user(user_id) do
    GenServer.cast(__MODULE__, {:put_user, user_id})
  end

  def put_messages(original_message_id, message_ids) do
    GenServer.cast(__MODULE__, {:put_messages, original_message_id, message_ids})
  end

  def set_user_lifetime(user_id, lifetime) do
    GenServer.cast(__MODULE__, {:set_user_lifetime, user_id, lifetime})
  end

  @impl GenServer
  def init(:none) do
    state =
      case File.read("store") do
        {:ok, content} ->
          :erlang.binary_to_term(content)

        {:error, _} ->
          new_state = %State{}
          persist(new_state)
          new_state
      end

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_users, _, state) do
    {:reply, MapSet.new(Map.keys(state.users)), state}
  end

  @impl GenServer
  def handle_call({:get_user, user_id}, _, state) do
    {:reply, state.users[user_id], state}
  end

  @impl GenServer
  def handle_call({:get_messages, message_id}, _, state) do
    {:reply, Map.fetch(state.messages, message_id), state}
  end

  @impl GenServer
  def handle_call({:get_message_by_local, user_id, message_id}, _, state) do
    case Enum.find(state.messages, fn
           {_original, %Message{ids: ids}} ->
             ids[user_id] == message_id

           _ ->
             nil
         end) do
      nil ->
        {:reply, :error, state}

      {_original_message_id, message} ->
        {:reply, {:ok, message}, state}
    end
  end

  @impl GenServer
  def handle_cast({:put_user, user_id}, state) do
    state = %{state | users: Map.put(state.users, user_id, %User{})}
    persist(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:put_messages, original_message_id, message_ids}, state) do
    state = %{state | messages: Map.put(state.messages, original_message_id, message_ids)}
    persist(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_user_lifetime, user_id, lifetime}, state) do
    users = Map.update(state.users, user_id, %User{}, fn user -> %{user | lifetime: lifetime} end)
    state = %{state | users: users}
    persist(state)
    {:noreply, state}
  end

  defp persist(state) do
    File.write("store", :erlang.term_to_binary(state))
  end
end
