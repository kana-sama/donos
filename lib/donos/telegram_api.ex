defmodule Donos.TelegramAPI do
  use GenServer

  alias Donos.Client
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
      with {:ok, updates} <- Nadia.get_updates(offset: offset) do
        Enum.reduce(updates, offset, fn update, _ ->
          with %Update{message: %Message{} = message} <- update do
            Client.message(message.from.id, message.text)
          end

          update.update_id + 1
        end)
      else
        _ -> offset
      end

    schedule_polling()
    {:noreply, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, 100)
  end
end
