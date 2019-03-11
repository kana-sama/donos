defmodule Donos.NamesRegister do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :none, name: __MODULE__)
  end

  def new_name() do
    GenServer.call(__MODULE__, :new_name)
  end

  @impl GenServer
  def init(:none) do
    names_resource = Path.join(:code.priv_dir(:donos), "names.txt")
    names = File.read!(names_resource) |> String.split("\n")
    {:ok, names}
  end

  @impl GenServer
  def handle_call(:new_name, _, names) do
    name = Enum.random(names)
    {:reply, name, names}
  end
end
