defmodule Donos.Session do
  use GenServer

  defmodule State do
    defstruct [:user_id, :name]
  end

  alias Donos.{SessionsRegister, Chat}

  @timeout 1000 * 60 * 5

  def start(user_id) do
    GenServer.start(__MODULE__, user_id)
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

  def stop(user_id) do
    GenServer.stop(get(user_id))
  end

  def gen_name do
    form_data = URI.encode_query(fam: 1, imya: 1, otch: 0, pol: 1, count: 1)
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    "http://freegenerator.ru/fio"
    |> HTTPoison.post!(form_data, headers)
    |> Map.get(:body)
    |> String.slice(0..-7)
  end

  def message(user_id, message) do
    GenServer.cast(get(user_id), {:message, message})
  end

  def photo(user_id, caption, photo) do
    GenServer.cast(get(user_id), {:photo, caption, photo})
  end

  @impl GenServer
  def init(user_id) do
    SessionsRegister.register(user_id, self())
    name = gen_name()
    session = %State{user_id: user_id, name: name}
    Chat.local_message(user_id, "Ваше имя: #{name}")
    {:ok, session, @timeout}
  end

  @impl GenServer
  def handle_cast({:message, message}, session) do
    Chat.broadcast_session_message(session.user_id, session.name, message)
    {:noreply, session, @timeout}
  end

  @impl GenServer
  def handle_cast({:photo, caption, photo}, session) do
    Chat.broadcast_session_photo(session.user_id, session.name, caption, photo)
    {:noreply, session, @timeout}
  end

  @impl GenServer
  def handle_info(:timeout, session) do
    {:stop, :normal, session}
  end

  @impl GenServer
  def terminate(_reason, session) do
    SessionsRegister.unregister(session.user_id)
    Chat.local_message(session.user_id, "Ваша сессия кончилась")
  end
end
