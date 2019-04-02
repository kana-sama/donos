defmodule Donos.Message do
  def transform(text, transformations) do
    transformations = transformations || []

    split_text(text, transformations)
    |> Enum.map(fn
      {%{type: "pre"} = transformation, text} -> {transformation, text}
      {%{type: "code"} = transformation, text} -> {transformation, text}
      {transformation, text} -> {transformation, escape(text)}
      text -> escape(text)
    end)
    |> Enum.map(fn
      {%{type: "italic"}, text} -> "_#{text}_"
      {%{type: "bold"}, text} -> "*#{text}*"
      {%{type: "code"}, text} -> "`#{text}`"
      {%{type: "pre"}, text} -> "```\n#{text}```"
      {%{type: "text_link", url: url}, text} -> "[#{text}](#{url})"
      {_transformation, text} -> text
      text -> text
    end)
    |> Enum.join()
  end

  @chars_to_escape ["*", "_", "[", "`"]

  def escape(text) do
    Enum.reduce(@chars_to_escape, text, fn char, text ->
      String.replace(text, char, "\\" <> char)
    end)
  end

  def split_text(text, transformations) do
    do_split_text(text, 0, transformations)
  end

  defp do_split_text(text, i, [%{offset: i} = t | ts]) do
    chunk = {t, String.slice(text, t.offset, t.length)}
    [chunk | do_split_text(text, i + t.length, ts)]
  end

  defp do_split_text(text, i, [t | _] = ts) do
    chunk = String.slice(text, i, t.offset - i)
    [chunk | do_split_text(text, t.offset, ts)]
  end

  defp do_split_text(text, i, []) do
    case String.slice(text, i..-1) do
      "" -> []
      chunk -> [chunk]
    end
  end
end
