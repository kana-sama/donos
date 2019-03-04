defmodule DonosTest do
  use ExUnit.Case
  doctest Donos

  test "greets the world" do
    assert Donos.hello() == :world
  end
end
