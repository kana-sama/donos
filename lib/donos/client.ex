defmodule Donos.Client do
  use GenServer

  alias Donos.{Clients, Chat, User}

  @timeout 1000 * 60 * 5

  def start(user_id) do
    GenServer.start(__MODULE__, user_id)
  end

  def gen_name do
    Range.new(?a, ?z)
    |> Enum.take_random(:rand.uniform(5) + 5)
    |> List.to_string()
    |> String.capitalize()
  end

  def message(user_id, message) do
    client = Clients.get_or_register(user_id)
    GenServer.cast(client, {:message, message})
  end

  @impl GenServer
  def init(user_id) do
    user = %User{id: user_id, name: gen_name()}
    Chat.system_message("User #{user.name} connected")
    {:ok, user, @timeout}
  end

  @impl GenServer
  def handle_cast({:message, message}, user) do
    Chat.user_message(user, message)
    {:noreply, user, @timeout}
  end

  @impl GenServer
  def handle_info(:timeout, user) do
    {:stop, :normal, user}
  end

  @impl GenServer
  def terminate(_reason, user) do
    Clients.unregister(user.id)
    Chat.system_message("User #{user.name} disconnected")
  end
end
