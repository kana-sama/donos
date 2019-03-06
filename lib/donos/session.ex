defmodule Donos.Session do
  use GenServer

  alias Donos.{SessionsRegister, Bot}

  defmodule State do
    defstruct [:user_id, :name]
  end

  @timeout Application.get_env(:donos, :session_life)

  def start(user_id) do
    GenServer.start(__MODULE__, user_id)
  end

  def stop(user_id) do
    GenServer.stop(get(user_id))
  end

  def get(user_id) do
    case SessionsRegister.get(user_id) do
      {:ok, session} ->
        session

      :error ->
        {:ok, session} = start(user_id)
        session
    end
  end

  def get_name(user_id) do
    GenServer.call(get(user_id), :get_name)
  end

  @impl GenServer
  def init(user_id) do
    name = gen_name()

    SessionsRegister.register(user_id, self())
    session = %State{user_id: user_id, name: name}

    Bot.Logic.local_system_message(user_id, "Ваше имя: #{name}")

    {:ok, session, @timeout}
  end

  @impl GenServer
  def handle_call(:get_name, _, session) do
    {:reply, session.name, session, @timeout}
  end

  @impl GenServer
  def handle_info(:timeout, session) do
    {:stop, :normal, session}
  end

  @impl GenServer
  def terminate(_reason, session) do
    SessionsRegister.unregister(session.user_id)
    Bot.Logic.local_system_message(session.user_id, "Ваша сессия кончилась")
  end

  defp gen_name do
    Faker.Pokemon.name()
  end
end
