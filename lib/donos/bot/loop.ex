defmodule Donos.Bot.Loop do
  use GenServer

  alias Donos.Bot.Logic
  alias Nadia.Model.Update

  @delay 100

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
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
          Logic.handle(update)
          return(update_id + 1)
        rescue
          error ->
            IO.inspect(error)
            return(offset)
        end

      {:ok, []} ->
        return(offset)

      error ->
        IO.inspect(error)
        return(offset)
    end
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:noreply, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, @delay)
  end
end
