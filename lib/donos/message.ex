defmodule Donos.Message do
  def to_markdown(text, entities) do
    text
    |> split_by_entities(entities || [])
    |> Enum.map(&apply_entity/1)
    |> Enum.join()
  end

  def split_by_entities(text, entities) do
    do_split_by_entities(text, entities, 0)
  end

  defp do_split_by_entities(text, [%{offset: index} = entity | entities], index) do
    chunk = String.slice(text, entity.offset, entity.length)
    [{chunk, entity} | do_split_by_entities(text, entities, index + entity.length)]
  end

  defp do_split_by_entities(text, [entity | _] = entities, index) do
    chunk = String.slice(text, index, entity.offset - index)
    [{chunk, :none} | do_split_by_entities(text, entities, entity.offset)]
  end

  defp do_split_by_entities(text, [], index) do
    if index < String.length(text) do
      [{text |> String.slice(index..-1), :none}]
    else
      []
    end
  end

  @special_chars ["*", "_", "[", "`"]
  def escape(text) do
    Enum.reduce(@special_chars, text, fn char, text ->
      String.replace(text, char, "\\" <> char)
    end)
  end

  def apply_entity({text, entity}) do
    case entity do
      %{type: "italic"} -> "_#{escape(text)}_"
      %{type: "bold"} -> "*#{escape(text)}*"
      %{type: "code"} -> "`#{escape(text)}`"
      %{type: "pre"} -> "```\n#{text}```"
      %{type: "text_link", url: url} -> "[#{escape(text)}](#{url})"
      _ -> escape(text)
    end
  end
end
