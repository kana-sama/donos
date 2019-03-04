defmodule Donos.Chat do
  alias Donos.{User, Clients}

  def system_message(message) do
    message(%User{name: "System", id: :system}, message)
  end

  def user_message(user, message) do
    message(user, message)
  end

  defp message(author, message) do
    spawn(fn ->
      message = "[#{author.name}]\n #{message}"

      for user_id <- Clients.users(), user_id != author.id do
        Nadia.send_message(user_id, message)
      end
    end)
  end
end
