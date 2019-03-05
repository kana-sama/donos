defmodule Donos.TelegramAPI do
  use GenServer

  alias Donos.Session
  alias Nadia.Model.{Update, Message}

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
            %Update{message: %Message{from: user, text: message}} when is_binary(message) ->
              cond do
                not String.starts_with?(message, "/") ->
                  Session.message(user.id, message)

                message == "/relogin" ->
                  Session.stop(user.id)
                  Session.start(user.id)
              end

            %Update{message: %Message{from: user, photo: [_ | _] = photos, caption: caption}} ->
              photo = Enum.at(photos, -1).file_id
              Session.photo(user.id, caption || "", photo)

            _ ->
              :ok
          end

          update.update_id + 1
        end)
      rescue
        error -> offset
      catch
        _ -> offset
      end

    schedule_polling()
    {:noreply, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, 100)
  end
end
