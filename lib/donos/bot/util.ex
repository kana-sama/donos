defmodule Donos.Bot.Util do
  alias Donos.{Session, Store}

  def send_message(chat_id, message, options \\ []) do
    Nadia.send_message(chat_id, format_message(message),
      reply_to_message_id: options[:reply_to],
      parse_mode: "markdown"
    )
  end

  def broadcast_content(message, action) do
    name = Session.get_name(message.from.id)

    related =
      users_for_broadcast(message.from.id)
      |> Enum.reduce(Map.new(), fn user_id, message_ids ->
        case action.(user_id, name) do
          {:ok, new_message} ->
            Map.put(message_ids, user_id, new_message.message_id)

          _ ->
            message_ids
        end
      end)

    related =
      if Application.get_env(:donos, :show_own_messages?) do
        related
      else
        Map.put(related, message.from.id, message.message_id)
      end

    Store.Message.put(message.message_id, name, related)
  end

  def format_message({:system, text}) do
    "_#{text}_"
  end

  def format_message({:post, name, text}) do
    "*#{name}*\n#{text}"
  end

  def format_message({:edit, name, text}) do
    "*#{name}* _(ред.)_\n#{text}"
  end

  def format_message({:announce, name, media}) do
    "*#{name}* отправил #{media}"
  end

  def get_message_for_reply(message, user_id) do
    with %{message_id: reply_to} <- message.reply_to_message,
         {:ok, %Store.Message{related: related}} <-
           Store.Message.get_by_related(message.from.id, reply_to) do
      related[user_id]
    else
      _ -> nil
    end
  end

  defp users_for_broadcast(current_user_id) do
    users = Store.User.ids()

    if Application.get_env(:donos, :show_own_messages?) do
      users
    else
      MapSet.delete(users, current_user_id)
    end
  end
end
