defmodule Donos.Chat do
  use GenServer

  alias Donos.Users

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def local_message(user_id, message) do
    GenServer.cast(__MODULE__, {:local_message, user_id, message})
  end

  def broadcast_session_message(user_id, user_name, message) do
    GenServer.cast(__MODULE__, {:broadcast_session_message, user_id, user_name, message})
  end

  def broadcast_session_photo(user_id, user_name, caption, photo) do
    GenServer.cast(__MODULE__, {:broadcast_session_photo, user_id, user_name, caption, photo})
  end

  @impl GenServer
  def init(:none) do
    {:ok, :none}
  end

  @impl GenServer
  def handle_cast({:local_message, user_id, message}, :none) do
    Nadia.send_message(user_id, "_#{message}_", parse_mode: "markdown")
    Users.put(user_id)
    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:broadcast_session_message, user_id, user_name, message}, :none) do
    message = "*#{user_name}*\n#{message}"

    for receiver_user_id <- users_to_broadcast(user_id) do
      Nadia.send_message(receiver_user_id, message, parse_mode: "markdown")
    end

    Users.put(user_id)

    {:noreply, :none}
  end

  @impl GenServer
  def handle_cast({:broadcast_session_photo, user_id, user_name, caption, photo}, :none) do
    caption = "#{user_name}\n#{caption}"

    for receiver_user_id <- users_to_broadcast(user_id) do
      Nadia.send_photo(receiver_user_id, photo, caption: caption)
    end

    Users.put(user_id)

    {:noreply, :none}
  end

  def users_to_broadcast(current_user_id) do
    users = Users.get()

    if Donos.Application.show_own_messages?() do
      users
    else
      MapSet.delete(users, current_user_id)
    end
  end
end
