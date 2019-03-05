defmodule Donos.Users do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def put(user_id) do
    GenServer.cast(__MODULE__, {:put, user_id})
  end

  @impl GenServer
  def init(:none) do
    case File.read("users") do
      {:ok, content} ->
        {:ok, :erlang.binary_to_term(content)}

      {:error, _} ->
        users = MapSet.new()
        write(users)
        {:ok, users}
    end
  end

  @impl GenServer
  def handle_call(:get, _, users) do
    {:reply, users, users}
  end

  @impl GenServer
  def handle_cast({:put, user_id}, users) do
    users = MapSet.put(users, user_id)
    write(users)
    {:noreply, users}
  end

  defp write(users) do
    File.write("users", :erlang.term_to_binary(users))
  end
end
