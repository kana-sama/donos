defmodule Donos.Chat do
  use GenServer

  alias Donos.Store

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def local_message(user_id, message) do
    GenServer.cast(__MODULE__, {:local_message, user_id, message})
  end

  def broadcast_message(user_id, user_name, original_message_id, text) do
    GenServer.cast(
      __MODULE__,
      {:broadcast_message, user_id, user_name, original_message_id, text}
    )
  end

  def broadcast_photo(user_id, user_name, caption, photo) do
    GenServer.cast(__MODULE__, {:broadcast_photo, user_id, user_name, caption, photo})
  end

  def broadcast_sticker(user_id, user_name, sticker) do
    GenServer.cast(__MODULE__, {:broadcast_sticker, user_id, user_name, sticker})
  end

  def edit_text(message_id, text) do
    GenServer.cast(__MODULE__, {:edit_text, message_id, text})
  end

  @impl GenServer
  def init(:none) do
    {:ok, :none}
  end

  @impl GenServer
  def handle_cast({:local_message, user_id, message}, :none) do
    Nadia.send_message(user_id, "_#{message}_", parse_mode: "markdown")
    Store.put_user(user_id)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:broadcast_message, user_id, user_name, original_message_id, text}, :none) do
    text = format_message(user_name, text)

    message_ids =
      Enum.reduce(users_to_broadcast(user_id), Map.new(), fn user_id, message_ids ->
        case Nadia.send_message(user_id, text, parse_mode: "markdown") do
          {:ok, message} ->
            Map.put(message_ids, user_id, message.message_id)

          {:error, _error} ->
            message_ids
        end
      end)

    Store.put_user(user_id)
    Store.put_messages(original_message_id, {user_name, message_ids})

    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:broadcast_photo, user_id, user_name, caption, photo}, :none) do
    caption = "#{user_name}\n#{caption}"

    for receiver_user_id <- users_to_broadcast(user_id) do
      Nadia.send_photo(receiver_user_id, photo, caption: caption)
    end

    Store.put_user(user_id)

    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:broadcast_sticker, user_id, user_name, sticker}, :none) do
    for receiver_user_id <- users_to_broadcast(user_id) do
      Nadia.send_message(receiver_user_id, "*#{user_name}* послал стикер", parse_mode: "markdown")
      Nadia.send_sticker(receiver_user_id, sticker)
    end

    Store.put_user(user_id)

    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:edit_text, message_id, text}, :none) do
    with {:ok, {user_name, related_messages}} <- Store.get_messages(message_id) do
      text = format_message(user_name, text, :edited)

      for {user_id, related_message_id} <- related_messages do
        Nadia.edit_message_text(user_id, related_message_id, "", text, parse_mode: "markdown")
      end
    end

    {:noreply, :none}
  end

  def users_to_broadcast(current_user_id) do
    users = Store.get_users()

    if Donos.Application.show_own_messages?() do
      users
    else
      MapSet.delete(users, current_user_id)
    end
  end

  defp format_message(user_name, text) do
    "*#{user_name}*\n#{text}"
  end

  defp format_message(user_name, text, :edited) do
    format_message(user_name <> " (отредактировано)", text)
  end
end
