defmodule Donos.Bot.Loop do
  use GenServer

  alias Donos.Bot.Logic
  alias Nadia.Model.Update

  @delay 100
  @blacklist Application.get_env(:donos, :blacklist) || MapSet.new()

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  @impl GenServer
  def init(:none) do
    schedule_polling()
    {:ok, 0}
  end

  defp author_id(%{message: %{from: id}}), do: id
  defp author_id(%{edited_message: %{from: id}}), do: id
  defp author_id(_), do: nil

  @impl GenServer
  def handle_info(:poll, offset) do
    new_offset =
      case Nadia.get_updates(offset: offset, limit: 1, timeout: 100) do
        {:ok, [%Update{update_id: update_id} = update | _]} when update_id >= offset ->
          unless MapSet.member?(@blacklist, author_id(update)) do
            Logic.handle(update)
          end

          update_id + 1

        _ ->
          offset
      end

    schedule_polling()
    {:noreply, new_offset}
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:noreply, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, @delay)
  end
end
