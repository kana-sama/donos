defmodule Donos.Bot.Loop do
  use GenServer

  alias Donos.Bot.Logic
  alias Nadia.Model.{Update, Message}
  alias Nadia.Model.{Audio, Document, Sticker, Video, Voice, Contact, Location}

  @delay 100

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
    case Nadia.get_updates(offset: offset, limit: 1, timeout: 100) do
      {:ok, [update | _]} ->
        try do
          handle_update(update)
          return(update.update_id + 1)
        rescue
          error ->
            IO.inspect(error)
            return(offset)
        end

      {:ok, []} ->
        return(offset)

      {:error, reason} ->
        IO.inspect(reason)
        return(offset)
    end
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:stop, :normal, offset}
  end

  defp handle_update(%Update{message: %Message{text: <<"/", command::binary>>} = message}) do
    Logic.post({:command, command}, message)
  end

  defp handle_update(%Update{message: %Message{text: text} = message}) when is_binary(text) do
    Logic.post({:text, text}, message)
  end

  defp handle_update(%Update{message: %Message{audio: %Audio{}} = message}) do
    Logic.post({:audio, message.audio.file_id}, message)
  end

  defp handle_update(%Update{message: %Message{document: %Document{}} = message}) do
    Logic.post({:document, message.document.file_id}, message)
  end

  defp handle_update(%Update{message: %Message{photo: [_ | _]} = message}) do
    Logic.post({:photo, Enum.at(message.photos, -1).file_id}, message)
  end

  defp handle_update(%Update{message: %Message{sticker: %Sticker{}} = message}) do
    Logic.post({:sticker, message.sticker.file_id}, message)
  end

  defp handle_update(%Update{message: %Message{video: %Video{}} = message}) do
    Logic.post({:video, message.video.file_id}, message)
  end

  defp handle_update(%Update{message: %Message{voice: %Voice{}} = message}) do
    Logic.post({:voice, message.voice.file_id}, message)
  end

  defp handle_update(%Update{message: %Message{contact: %Contact{}} = message}) do
    Logic.post({:contact, message.contact.phone_number, message.contact.first_name}, message)
  end

  defp handle_update(%Update{message: %Message{location: %Location{}} = message}) do
    Logic.post({:location, message.location.latitude, message.location.longitude}, message)
  end

  defp handle_update(%Update{edited_message: %{text: text} = message}) when is_binary(text) do
    Logic.edit({:text, text}, message)
  end

  defp handle_update(update) do
    IO.inspect({:unkown_command, update})
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, @delay)
  end

  defp return(offset) do
    schedule_polling()
    {:noreply, offset}
  end
end
