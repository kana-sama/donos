defmodule Donos.MessageTest do
  use ExUnit.Case
  doctest Donos.Message
  alias Donos.Message

  test "to_markdown" do
    assert Message.to_markdown("* hello _ world", [
             %{offset: 2, length: 5, type: "bold"},
             %{offset: 10, length: 5, type: "italic"}
           ]) == "\\* *hello* \\_ _world_"
  end

  test "split_by_entities" do
    input = "Hello world"

    assert_result = fn entities, result ->
      assert Message.split_by_entities(input, entities) == result
    end

    assert_result.([], [{input, :none}])

    assert_result.([%{offset: 0, length: 11, type: "code"}], [
      {input, %{offset: 0, length: 11, type: "code"}}
    ])

    assert_result.(
      [%{offset: 1, length: 1, type: "a"}, %{offset: 3, length: 2, type: "b"}],
      [
        {"H", :none},
        {"e", %{offset: 1, length: 1, type: "a"}},
        {"l", :none},
        {"lo", %{offset: 3, length: 2, type: "b"}},
        {" world", :none}
      ]
    )
  end

  test "escape" do
    assert Message.escape("hello * ```world``` _ 2 [1]") ==
             "hello \\* \\`\\`\\`world\\`\\`\\` \\_ 2 \\[1]"
  end
end
