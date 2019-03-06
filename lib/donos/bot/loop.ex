defmodule Donos.Bot.Loop do
  use GenServer

  alias Donos.Bot.Logic
  alias Nadia.Model.{Update, Message}
  alias Nadia.Model.{Audio, Document, Sticker, Video, Voice, Contact, Location}

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
            %Update{message: %Message{text: <<"/", command::binary>>} = message} ->
              Logic.post({:command, command}, message)

            %Update{message: %Message{text: text} = message} when is_binary(text) ->
              Logic.post({:text, text}, message)

            %Update{message: %Message{audio: %Audio{} = audio} = message} ->
              Logic.post({:audio, audio.file_id}, message)

            %Update{message: %Message{document: %Document{} = document} = message} ->
              Logic.post({:document, document.file_id}, message)

            %Update{message: %Message{photo: [_ | _] = photos} = message} ->
              Logic.post({:photo, Enum.at(photos, -1).file_id}, message)

            %Update{message: %Message{sticker: %Sticker{} = sticker} = message} ->
              Logic.post({:sticker, sticker.file_id}, message)

            %Update{message: %Message{video: %Video{} = video} = message} ->
              Logic.post({:video, video.file_id}, message)

            %Update{message: %Message{voice: %Voice{} = voice} = message} ->
              Logic.post({:voice, voice.file_id}, message)

            %Update{message: %Message{contact: %Contact{} = contact} = message} ->
              Logic.post({:contact, contact.phone_number, contact.first_name}, message)

            %Update{message: %Message{location: %Location{} = location} = message} ->
              Logic.post({:location, location.latitude, location.longitude}, message)

            %Update{edited_message: %{text: text} = message} when is_binary(text) ->
              Logic.edit({:text, text}, message)

            _ ->
              IO.inspect({:unkown_command, update})
          end

          update.update_id + 1
        end)
      rescue
        error ->
          IO.inspect({:logic_error, error})
          offset
      end

    schedule_polling()
    {:noreply, offset}
  end

  @impl GenServer
  def handle_info({:ssl_closed, _}, offset) do
    {:stop, :normal, offset}
  end

  defp schedule_polling() do
    Process.send_after(self(), :poll, 300)
  end
end
