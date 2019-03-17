defmodule Donos.NamesRegister do
  use Agent

  def start_link(_) do
    Agent.start_link(&init/0, name: __MODULE__)
  end

  def init do
    Path.join(:code.priv_dir(:donos), "names.txt")
    |> File.read!()
    |> String.split("\n")
  end

  def new_name do
    Agent.get(__MODULE__, fn names ->
      Enum.random(names)
    end)
  end
end
