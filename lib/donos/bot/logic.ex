defmodule Donos.Bot.Logic do
  use GenServer

  alias Donos.{Store, Session}
  alias Nadia.Model.{Update, Message}
  alias Nadia.Model.{Audio, Document, Sticker, Video, Voice, Contact, Location}

  import Donos.Bot.Util

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def handle(update) do
    GenServer.cast(__MODULE__, {:handle, update})
  end

  @impl GenServer
  def init(:none) do
    {:ok, :none}
  end

  @impl GenServer
  def handle_cast({:handle, %Update{message: %Message{} = message}}, :none) do
    handle_message(message)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:handle, %Update{edited_message: %{} = message}}, :none) do
    handle_edited_message(message)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:handle, update}, :none) do
    IO.inspect({:unkown_update, update})
    {:noreply, :none}
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:noreply, offset}
  end

  defp handle_message(%{text: "/start"} = message) do
    Store.User.put(message.from.id)
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

  defp handle_message(%{text: "/deanon"} = message) do
    name = Session.get_name(message.from.id)
    user_name = [message.from.first_name, message.from.last_name] |> Enum.join(" ")
    user_link = "tg://user?id=#{message.from.id}"
    deanon_response = "_Настоящая личность_ *#{name}* _-_ *#{user_name}* ([ссылка](#{user_link}))"

    broadcast_content(message, fn user_id, _name ->
      send_message(user_id, deanon_response)
    end)

    response = "_Вы сдеанонились._ /relogin _для создания новой сессии_"
    send_message(message.from.id, response)
  end

  defp handle_message(%{text: "/getsession"} = message) do
    lifetime = Session.get_lifetime(message.from.id)
    response = "Длина сессии: #{Duration.format(lifetime)}"
    send_message(message.from.id, {:system, response})
  end

  defp handle_message(%{text: "/setsession"} = message) do
    response =
      [
        "_Формат_:```",
        "/setsession 10 (10 минут)",
        "/setsession 1d 1h 1m (1 день, 1 час и 1 минута)",
        "/setsession 1d 1 (1 день и 1 минута)",
        "```"
      ]
      |> Enum.join("\n")

    send_message(message.from.id, response)
  end

  defp handle_message(%{text: <<"/setsession ", lifetime::binary>>} = message) do
    response =
      with lifetime when is_integer(lifetime) <- Duration.parse(lifetime),
           :ok <- Session.set_lifetime(message.from.id, lifetime) do
        "Твоя новая длина сессии: #{Duration.format(lifetime)}"
      else
        {:error, reason} ->
          "Ошибка: #{reason}"
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
    text = Donos.Message.to_markdown(text, message.entities)

    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:post, name, text}, reply_to: get_message_for_reply(message, user_id))
    end)
  end

  defp handle_message(%{audio: %Audio{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "аудио"})

      Nadia.send_audio(user_id, file_id,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{document: %Document{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "файл"})

      Nadia.send_document(user_id, file_id,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{photo: [_ | _] = photos} = message) do
    file_id = Enum.at(photos, -1).file_id

    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "пикчу"})

      Nadia.send_photo(user_id, file_id,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
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
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{voice: %Voice{file_id: file_id}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "голосовое сообщение"})

      Nadia.send_voice(user_id, file_id,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{contact: %Contact{} = contact} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "контакт"})

      Nadia.send_contact(user_id, contact.phone_number, contact.first_name,
        last_name: contact.last_name,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(%{location: %Location{latitude: latitude, longitude: longitude}} = message) do
    broadcast_content(message, fn user_id, name ->
      send_message(user_id, {:announce, name, "местоположение"})

      Nadia.send_location(user_id, latitude, longitude,
        caption: Donos.Message.to_markdown(message.caption, message.entities),
        reply_to: get_message_for_reply(message, user_id)
      )
    end)
  end

  defp handle_message(message) do
    IO.inspect({:unkown_message, message})
  end

  defp handle_edited_message(%{caption: caption} = message) when is_binary(caption) do
    caption = Donos.Message.to_markdown(caption, message[:caption_entities])

    broadcast_edit(message, fn user_id, _user_name, related_message_id ->
      Nadia.edit_message_caption(user_id, related_message_id, "",
        caption: caption,
        parse_mode: "markdown"
      )
    end)
  end

  defp handle_edited_message(%{text: text} = message) when is_binary(text) do
    text = Donos.Message.to_markdown(text, message[:entities])

    broadcast_edit(message, fn user_id, user_name, related_message_id ->
      text = format_message({:edit, user_name, text})
      Nadia.edit_message_text(user_id, related_message_id, "", text, parse_mode: "markdown")
    end)
  end

  defp handle_edited_message(message) do
    IO.inspect({:unkown_edited_message, message})
  end
end
