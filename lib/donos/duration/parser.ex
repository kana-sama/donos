defmodule Duration.Parser do
  def parse(source) do
    case do_duration(source) do
      {:ok, duration, ""} ->
        duration

      _ ->
        :error
    end
  end

  defp do_duration(source) do
    do_duration(source, 0)
  end

  defp do_duration("", duration) do
    {:ok, duration, ""}
  end

  defp do_duration(source, duration) do
    with {:ok, value, source} <- do_spaced_value(source) do
      do_duration(source, duration + value)
    end
  end

  defp do_spaced_value(source) do
    with {:ok, _, source} <- do_spaces(source),
         {:ok, value, source} <- do_value(source),
         {:ok, _, source} <- do_spaces(source) do
      {:ok, value, source}
    end
  end

  defp do_spaces(<<" ", rest::binary>>) do
    do_spaces(rest)
  end

  defp do_spaces(source) do
    {:ok, nil, source}
  end

  defp do_value(source) do
    with {:ok, number, source} <- do_number(source) do
      case do_unit(source) do
        {:ok, unit, source} ->
          {:ok, number * unit, source}

        :error ->
          {:ok, number, source}
      end
    end
  end

  defp do_unit(<<"d", rest::binary>>), do: {:ok, 60 * 24, rest}
  defp do_unit(<<"h", rest::binary>>), do: {:ok, 60, rest}
  defp do_unit(<<"m", rest::binary>>), do: {:ok, 1, rest}
  defp do_unit(_source), do: :error

  defp do_number(source) do
    with {:ok, digits, source} <- do_digits(source) do
      number = List.foldr(digits, 0, fn digit, number -> number * 10 + digit end)
      {:ok, number, source}
    end
  end

  defguardp is_digit(code) when code >= 48 and code <= 57

  defp do_digits(source) do
    do_digits(source, [])
  end

  defp do_digits(<<digit, rest::binary>>, digits) when is_digit(digit) do
    do_digits(rest, [digit - 48 | digits])
  end

  defp do_digits(_source, []) do
    :error
  end

  defp do_digits(source, digits) do
    {:ok, digits, source}
  end
end
