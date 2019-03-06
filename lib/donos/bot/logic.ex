# TODO: escape markdown

defmodule Donos.Bot.Logic do
  use GenServer

  alias Donos.{Session, Store}

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def local_system_message(user_id, message) do
    GenServer.cast(__MODULE__, {:local_system_message, user_id, message})
  end

  def post(content, message) do
    GenServer.cast(__MODULE__, {:post, content, message})
  end

  def edit(content, message) do
    GenServer.cast(__MODULE__, {:edit, content, message})
  end

  @impl GenServer
  def init(:none) do
    {:ok, :none}
  end

  @impl GenServer
  def handle_cast({:post, content, message}, :none) do
    handle_post(content, message)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:edit, content, message}, :none) do
    handle_edit(content, message)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:local_system_message, user_id, message}, :none) do
    send_markdown(user_id, {:system, message})
    {:noreply, :none}
  end

  def handle_post({:command, "start"}, message) do
    Store.put_user(message.from.id)
    send_markdown(message.from.id, {:system, "Привет анон, это анонимный чат"})
  end

  def handle_post({:command, "ping"}, message) do
    send_markdown(message.from.id, {:system, "pong"})
  end

  def handle_post({:command, "relogin"}, message) do
    Session.stop(message.from.id)
    Session.start(message.from.id)
  end

  def handle_post({:command, command}, message) do
    send_markdown(message.from.id, {:system, "Команда не поддерживается: #{command}"})
  end

  def handle_post({:text, text}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:post, name, text})
    end)
  end

  def handle_post({:audio, audio}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "аудио"})
      Nadia.send_audio(user_id, audio, caption: message.caption)
    end)
  end

  def handle_post({:document, document}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "файл"})
      Nadia.send_document(user_id, document, caption: message.caption)
    end)
  end

  def handle_post({:sticker, sticker}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "стикер"})
      Nadia.send_sticker(user_id, sticker)
    end)
  end

  def handle_post({:video, video}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "видео"})
      Nadia.send_video(user_id, video, caption: message.caption)
    end)
  end

  def handle_post({:voice, voice}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "голосовое сообщение"})
      Nadia.send_voice(user_id, voice)
    end)
  end

  def handle_post({:contact, phone_number, first_name}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "контакт"})
      Nadia.send_contact(user_id, phone_number, first_name, last_name: message.contact.last_name)
    end)
  end

  def handle_post({:location, latitude, longitude}, message) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "местоположение"})
      Nadia.send_location(user_id, latitude, longitude)
    end)
  end

  def handle_post(content, message) do
    IO.inspect({:post, content, message})
    {:noreply, :none}
  end

  def handle_edit({:text, text}, message) do
    with {:ok, {name, related_messages}} <- Store.get_messages(message.message_id) do
      text = format_message({:edit, name, text})

      IO.puts("here")

      for {user_id, related_message_id} <- related_messages do
        Nadia.edit_message_text(user_id, related_message_id, "", text, parse_mode: "markdown")
      end
    end
  end

  def handle_edit(content, message) do
    IO.inspect({:edit, content, message})
  end

  defp broadcast_content(message, action) do
    name = Session.get_name(message.from.id)

    message_ids =
      Enum.reduce(users_to_broadcast(message.from.id), Map.new(), fn user_id, message_ids ->
        case action.(user_id, name) do
          {:ok, message} ->
            Map.put(message_ids, user_id, message.message_id)

          {:error, _error} ->
            message_ids
        end
      end)

    Store.put_messages(message.message_id, {name, message_ids})
  end

  defp users_to_broadcast(current_user_id) do
    users = Store.get_users()

    if Application.get_env(:donos, :show_own_messages?) do
      users
    else
      MapSet.delete(users, current_user_id)
    end
  end

  defp send_markdown(chat_id, message) do
    Nadia.send_message(chat_id, format_message(message), parse_mode: "markdown")
  end

  defp format_message({:system, text}) do
    "_#{text}_"
  end

  defp format_message({:post, name, text}) do
    "*#{name}*\n#{text}"
  end

  defp format_message({:edit, name, text}) do
    "*#{name}* _(отредактировано)_\n#{text}"
  end

  defp format_message({:announce, name, media}) do
    "*#{name}* отправил #{media}"
  end
end
