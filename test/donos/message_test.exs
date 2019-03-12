defmodule Donos.MessageTest do
  use ExUnit.Case
  doctest Donos.Message
  alias Donos.Message

  test "transform" do
    assert Message.transform("* hello _ world", [
             %{offset: 2, length: 5, type: "bold"},
             %{offset: 10, length: 5, type: "italic"}
           ]) == "\\* *hello* \\_ _world_"
  end

  test "split_text" do
    input = "Hello world"

    assert_result = fn transformations, result ->
      assert Message.split_text(input, transformations) == result
    end

    assert_result.([], [input])

    assert_result.([%{offset: 0, length: 11, type: "code"}], [
      {%{offset: 0, length: 11, type: "code"}, input}
    ])

    assert_result.(
      [%{offset: 1, length: 1, type: "a"}, %{offset: 3, length: 2, type: "b"}],
      [
        "H",
        {%{offset: 1, length: 1, type: "a"}, "e"},
        "l",
        {%{offset: 3, length: 2, type: "b"}, "lo"},
        " world"
      ]
    )
  end

  test "escape" do
    assert Message.escape("hello * ```world``` _ 2 [1]") ==
             "hello \\* \\`\\`\\`world\\`\\`\\` \\_ 2 \\[1]"
  end
end
