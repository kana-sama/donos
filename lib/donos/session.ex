defmodule Donos.Session do
  use GenServer

  alias Donos.{SessionsRegister, Bot, Store}

  defmodule State do
    defstruct [:user_id, :name, :lifetime]
  end

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

  def get_lifetime(user_id) do
    GenServer.call(get(user_id), :get_lifetime)
  end

  def set_lifetime(user_id, lifetime) do
    GenServer.call(get(user_id), {:set_lifetime, lifetime})
  end

  @impl GenServer
  def init(user_id) do
    name = gen_name()

    lifetime =
      case Store.User.get(user_id) do
        %Store.User{lifetime: lifetime} ->
          lifetime

        _ ->
          Application.get_env(:donos, :session_lifetime)
      end

    session = %State{user_id: user_id, name: name, lifetime: lifetime}

    Bot.system_message(user_id, "Твое новое имя: #{name}")
    SessionsRegister.register(user_id, self())

    {:ok, session, session.lifetime}
  end

  @impl GenServer
  def handle_call(:get_name, _, session) do
    {:reply, session.name, session, session.lifetime}
  end

  @impl GenServer
  def handle_call(:get_lifetime, _, session) do
    {:reply, session.lifetime, session, session.lifetime}
  end

  @impl GenServer
  def handle_call({:set_lifetime, lifetime}, _, session) do
    cond do
      lifetime <= 0 ->
        {:reply, {:error, "сессия не может длиться так мало"}, session, session.lifetime}

      lifetime > Duration.from(:days, 2) ->
        {:reply, {:error, "сессия не может длиться больше суток"}, session, session.lifetime}

      true ->
        Store.User.set_lifetime(session.user_id, lifetime)
        {:reply, :ok, %{session | lifetime: lifetime}, lifetime}
    end
  end

  @impl GenServer
  def handle_info(:timeout, session) do
    {:stop, :normal, session}
  end

  @impl GenServer
  def terminate(_reason, session) do
    SessionsRegister.unregister(session.user_id)
    Bot.system_message(session.user_id, "Твоя сессия закончилась")
  end

  defp gen_name do
    Exmoji.all()
    |> Enum.take_random(5)
    |> Enum.map(&Exmoji.EmojiChar.render/1)
    |> Enum.join()
  end
end
