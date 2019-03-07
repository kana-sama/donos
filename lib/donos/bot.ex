defmodule Donos.Bot do
  use GenServer

  alias Donos.{Store, Session}
  alias Nadia.Model.{Update, Message}
  alias Nadia.Model.{Audio, Document, Sticker, Video, Voice, Contact, Location}

  @delay 100

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def system_message(user_id, message) do
    send_message(user_id, {:system, message})
  end

  @impl GenServer
  def init(:none) do
    schedule_polling()
    {:ok, 0}
  end

  defp return(offset) do
    schedule_polling()
    {:noreply, offset}
  end

  @impl GenServer
  def handle_info(:poll, offset) do
    case Nadia.get_updates(offset: offset, limit: 1, timeout: 100) do
      {:ok, [%Update{update_id: update_id} = update | _]} when update_id >= offset ->
        try do
          handle_update(update)
          return(update_id + 1)
        rescue
          error ->
            IO.inspect(error)
            return(offset)
        end

      {:ok, []} ->
        return(offset)

      {:error, reason} ->
        IO.inspect(reason)
        return(offset)

      error ->
        IO.inspect(error)
        return(offset)
    end
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:stop, :normal, offset}
  end

  defp handle_update(%Update{message: %Message{} = message}) do
    handle_message(message)
  end

  defp handle_update(%Update{edited_message: %{} = message}) do
    handle_edited_message(message)
  end

  defp handle_update(update) do
    IO.inspect({:unkown_update, update})
  end

  defp handle_message(%{text: "/start"} = message) do
    Store.put_user(message.from.id)
    Session.get(message.from.id)

    response = "Привет анон, это анонимный чат"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: "/ping"} = message) do
    send_message(message.from.id, {:system, "pong"})
  end

  defp handle_message(%{text: "/relogin"} = message) do
    Session.stop(message.from.id)
    Session.start(message.from.id)
  end

  defp handle_message(%{text: "/setname"} = message) do
    response = "Синтаксис: /setname %new_name%"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: <<"/setname ", name::binary>>} = message) do
    response =
      case Session.set_name(message.from.id, name) do
        {:ok, name} -> "Твоё новое имя: #{name}"
        {:error, reason} -> "Ошибка: #{reason}"
      end

    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: "/getsession"} = message) do
    lifetime = Session.get_lifetime(message.from.id)
    response = "Длина твоей сессии в минутах: #{div(lifetime, 1000 * 60)}"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: "/setsession"} = message) do
    response = "Нужно дописать длину сессии (в минутах) после /setsession"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: <<"/setsession ", lifetime::binary>>} = message) do
    response =
      try do
        lifetime = lifetime |> String.trim() |> String.to_integer()
        lifetime = lifetime * 1000 * 60

        case Session.set_lifetime(message.from.id, lifetime) do
          :ok -> "Твоя новая длина сессии (в минутах): #{div(lifetime, 1000 * 60)}"
          {:error, reason} -> "Ошибка: #{reason}"
        end
      rescue
        ArgumentError -> "Ошибка: невалидный аргумент"
      end

    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: "/whoami"} = message) do
    name = Session.get_name(message.from.id)
    response = "Твое имя: #{name}"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: <<"/", command::binary>>} = message) do
    response = "Команда не поддерживается: #{command}"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: text} = message) when is_binary(text) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:post, name, text}, reply_to: get_message_for_reply(message, user_id))
    end)
  end

  defp handle_message(%{audio: %Audio{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "аудио"})

      Nadia.send_audio(user_id, file_id,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{document: %Document{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "файл"})

      Nadia.send_document(user_id, file_id,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{photo: [_ | _] = photos} = message) do
    file_id = Enum.at(photos, -1).file_id

    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "пикчу"})

      Nadia.send_photo(user_id, file_id,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{sticker: %Sticker{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "стикер"})
      Nadia.send_sticker(user_id, file_id, reply_to: get_message_for_reply(message, user_id))
    end)
  end

  defp handle_message(%{video: %Video{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "видео"})

      Nadia.send_video(user_id, file_id,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{voice: %Voice{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "голосовое сообщение"})

      Nadia.send_voice(user_id, file_id,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{contact: %Contact{} = contact} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "контакт"})

      Nadia.send_contact(user_id, contact.phone_number, contact.first_name,
        last_name: contact.last_name,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{location: %Location{latitude: latitude, longitude: longitude}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "местоположение"})

      Nadia.send_location(user_id, latitude, longitude,
        caption: message.caption,
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(message) do
    IO.inspect({:unkown_message, message})
  end

  defp handle_edited_message(%{text: text} = message) when is_binary(text) do
    with {:ok, %Store.Message{} = stored_message} <- Store.get_messages(message.message_id) do
      text = format_message({:edit, stored_message.user_name, text})

      for {user_id, related_message_id} <- stored_message.ids do
        Nadia.edit_message_text(user_id, related_message_id, "", text, parse_mode: "markdown")
      end
    end
  end

  defp handle_edited_message(message) do
    IO.inspect({:unkown_edited_message, message})
  end

  defp schedule_polling() do
    IO.inspect("schedule_polling")
    Process.send_after(self(), :poll, @delay)
  end

  defp broadcast_content(message, action) do
    name = Session.get_name(message.from.id)

    message_ids =
      users_to_broadcast(message.from.id)
      |> Enum.reduce(Map.new(), fn user_id, message_ids ->
        case action.(user_id, name) do
          {:ok, new_message} ->
            Map.put(message_ids, user_id, new_message.message_id)

          _ ->
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

  def send_message(chat_id, message, options \\ []) do
    Nadia.send_message(chat_id, format_message(message),
      reply_to_message_id: options[:reply_to],
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
    "*#{name}* _(ред.)_\n#{text}"
  end

  defp format_message({:announce, name, media}) do
    "*#{name}* отправил #{media}"
  end

  defp get_message_for_reply(message, user_id) do
    with %{message_id: reply_to} <- message.reply_to_message,
         {:ok, %Store.Message{ids: ids}} <- Store.get_message_by_local(message.from.id, reply_to) do
      ids[user_id]
    else
      _ -> nil
    end
  end

  @impl GenServer
  def terminate(reason, state) do
    IO.inspect({:terminate, reason, state})
  end
end
