defmodule Donos.TelegramAPI do
  use GenServer

  alias Donos.{Session, Chat}
  alias Nadia.Model.{Update, Message, Sticker}

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  @impl GenServer
  def init(:none) do
    schedule_polling()
    {:ok, 0}
  end

  @impl GenServer
  def handle_info(:poll, offset) do
    offset =
      try do
        {:ok, updates} = Nadia.get_updates(offset: offset)

        Enum.reduce(updates, offset, fn update, _ ->
          case update do
            %Update{message: %Message{from: user, text: "/relogin"}} ->
              Session.stop(user.id)
              Session.start(user.id)

            %Update{message: %Message{from: user, text: <<"/", command::binary>>}} ->
              Chat.local_message(user.id, "Команда не поддерживается: #{command}")

            %Update{message: %Message{text: text} = message} when is_binary(text) ->
              Session.text(message.from.id, message.message_id, text)

            %Update{message: %Message{from: user, photo: [_ | _] = photos, caption: caption}} ->
              photo = Enum.at(photos, -1).file_id
              Session.photo(user.id, caption || "", photo)

            %Update{message: %Message{from: user, sticker: %Sticker{} = sticker}} ->
              Session.sticker(user.id, sticker.file_id)

            _ ->
              IO.inspect(update)
          end

          update.update_id + 1
        end)
      rescue
        error ->
          IO.inspect(error)
          offset
      catch
        error ->
          IO.inspect(error)
          offset
      end

    schedule_polling()
    {:noreply, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, 300)
  end
end
