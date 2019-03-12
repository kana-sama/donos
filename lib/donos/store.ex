defmodule Donos.Store do
  use GenServer

  @garbage_collector_duration Duration.from(:days, 1)
  @garbage_collector_interval Duration.from(:hours, 1)

  defmodule User do
    defstruct lifetime: Application.get_env(:donos, :session_lifetime)

    def ids() do
      GenServer.call(Donos.Store, :get_user_ids)
    end

    def get(user_id) do
      GenServer.call(Donos.Store, {:get_user, user_id})
    end

    def put(user_id) do
      GenServer.cast(Donos.Store, {:put_user, user_id})
    end

    def set_lifetime(user_id, lifetime) do
      GenServer.cast(Donos.Store, {:set_user_lifetime, user_id, lifetime})
    end
  end

  defmodule Message do
    defstruct [:user_name, :posted_at, {:related, Map.new()}]

    def get(message_id) do
      GenServer.call(Donos.Store, {:get_message, message_id})
    end

    def get_by_related(user_id, related_message_id) do
      GenServer.call(Donos.Store, {:get_message_by_related, user_id, related_message_id})
    end

    def put(message_id, user_name, related) do
      GenServer.cast(Donos.Store, {:put_message, message_id, user_name, related})
    end
  end

  defmodule State do
    defstruct users: Map.new(), messages: Map.new()
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  @impl GenServer
  def init(:none) do
    state =
      case File.read("store") do
        {:ok, content} ->
          :erlang.binary_to_term(content)

        _ ->
          %State{}
      end

    schedule_garbage_collector()
    {:ok, state, {:continue, :persist}}
  end

  @impl GenServer
  def handle_call(:get_user_ids, _, state) do
    {:reply, MapSet.new(Map.keys(state.users)), state}
  end

  @impl GenServer
  def handle_call({:get_user, user_id}, _, state) do
    {:reply, state.users[user_id], state}
  end

  @impl GenServer
  def handle_call({:get_message, message_id}, _, state) do
    {:reply, Map.fetch(state.messages, message_id), state}
  end

  @impl GenServer
  def handle_call({:get_message_by_related, user_id, related_message_id}, _, state) do
    message =
      Enum.find(state.messages, fn
        {_message_id, %Message{related: related}} ->
          related[user_id] == related_message_id

        _ ->
          nil
      end)

    reply =
      case message do
        {_message_id, message} ->
          {:ok, message}

        nil ->
          :error
      end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_cast({:put_user, user_id}, state) do
    user = %User{}

    state = put_in(state.users[user_id], user)
    {:noreply, state, {:continue, :persist}}
  end

  @impl GenServer
  def handle_cast({:put_message, message_id, user_name, related}, state) do
    message = %Message{
      user_name: user_name,
      posted_at: DateTime.utc_now(),
      related: related
    }

    state = put_in(state.messages[message_id], message)
    {:noreply, state, {:continue, :persist}}
  end

  @impl GenServer
  def handle_cast({:set_user_lifetime, user_id, lifetime}, state) do
    state = put_in(state.users[user_id].lifetime, lifetime)
    {:noreply, state, {:continue, :persist}}
  end

  @impl GenServer
  def handle_info(:collect_garbage, state) do
    now = DateTime.utc_now()

    messages =
      state.messages
      |> Enum.reject(&old_message?(now, &1))
      |> Enum.into(Map.new())

    state = %{state | messages: messages}

    schedule_garbage_collector()
    {:noreply, state, {:continue, :persist}}
  end

  @impl GenServer
  def handle_continue(:persist, state) do
    File.write("store", :erlang.term_to_binary(state))
    {:noreply, state}
  end

  defp old_message?(now, {_message_id, message}) do
    duration = DateTime.diff(now, message.posted_at, :millisecond)
    duration > @garbage_collector_duration
  end

  defp schedule_garbage_collector() do
    Process.send_after(self(), :collect_garbage, @garbage_collector_interval)
  end
end
