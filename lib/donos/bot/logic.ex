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
    reply_to = get_reply_to(message)
    handle_post(content, message, reply_to)
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

  def handle_post({:command, "start"}, message, _reply_to) do
    Store.put_user(message.from.id)
    send_markdown(message.from.id, {:system, "Привет анон, это анонимный чат"})
  end

  def handle_post({:command, "ping"}, message, _reply_to) do
    send_markdown(message.from.id, {:system, "pong"})
  end

  def handle_post({:command, "relogin"}, message, _reply_to) do
    Session.stop(message.from.id)
    Session.start(message.from.id)
  end

  def handle_post({:command, command}, message, _reply_to) do
    send_markdown(message.from.id, {:system, "Команда не поддерживается: #{command}"})
  end

  def handle_post({:text, text}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:post, name, text}, reply_to[user_id])
    end)
  end

  def handle_post({:audio, audio}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "аудио"})

      Nadia.send_audio(user_id, audio,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:document, document}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "файл"})

      Nadia.send_document(user_id, document,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:photo, photo}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "пикчу"})

      Nadia.send_photo(user_id, photo,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:sticker, sticker}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "стикер"})
      Nadia.send_sticker(user_id, sticker, reply_to: reply_to[user_id])
    end)
  end

  def handle_post({:video, video}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "видео"})

      Nadia.send_video(user_id, video,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:voice, voice}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "голосовое сообщение"})

      Nadia.send_voice(user_id, voice,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:contact, phone_number, first_name}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "контакт"})

      Nadia.send_contact(user_id, phone_number, first_name,
        caption: message.caption,
        last_name: message.contact.last_name,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post({:location, latitude, longitude}, message, reply_to) do
    broadcast_content(message, fn user_id, name ->
      send_markdown(user_id, {:announce, name, "местоположение"})

      Nadia.send_location(user_id, latitude, longitude,
        caption: message.caption,
        reply_to: reply_to[user_id]
      )
    end)
  end

  def handle_post(content, message) do
    IO.inspect({:post, content, message})
    {:noreply, :none}
  end

  def handle_edit({:text, text}, message) do
    with {:ok, %Store.Message{} = stored_message} <- Store.get_messages(message.message_id) do
      text = format_message({:edit, stored_message.user_name, text})
      IO.inspect(stored_message)

      for {user_id, related_message_id} <- stored_message.ids do
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
      users_to_broadcast(message.from.id)
      |> Enum.reduce(Map.new(), fn user_id, message_ids ->
        case action.(user_id, name) do
          {:ok, new_message} ->
            Map.put(message_ids, user_id, new_message.message_id)

          {:error, _error} ->
            message_ids
        end
      end)

    message_ids =
      if Application.get_env(:donos, :show_own_messages?) do
        message_ids
      else
        Map.put(message_ids, message.from.id, message.message_id)
      end

    Store.put_messages(message.message_id, %Store.Message{user_name: name, ids: message_ids})
  end

  defp users_to_broadcast(current_user_id) do
    users = Store.get_users()

    if Application.get_env(:donos, :show_own_messages?) do
      users
    else
      MapSet.delete(users, current_user_id)
    end
  end

  defp send_markdown(chat_id, message, reply_to \\ nil) do
    Nadia.send_message(chat_id, format_message(message),
      reply_to_message_id: reply_to,
      parse_mode: "markdown"
    )
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

  defp get_reply_to(message) do
    with %{message_id: reply_to} <- message.reply_to_message,
         {:ok, %Store.Message{ids: ids}} <- Store.get_message_by_local(message.from.id, reply_to) do
      ids
    else
      _ -> %{}
    end
  end
end
