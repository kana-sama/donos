defmodule Duration do
  @convert_map %{
    minutes: 1 * 1000 * 60,
    hours: 1 * 1000 * 60 * 60,
    days: 1 * 1000 * 60 * 60 * 24
  }

  def from(unit, n) do
    n * @convert_map[unit]
  end

  def to(unit, n) do
    div(n, @convert_map[unit])
  end

  def parse(source) when is_binary(source) do
    case Duration.Parser.parse(source) do
      :error ->
        {:error, "неверный формат"}

      duration ->
        from(:minutes, duration)
    end
  end

  def format(duration) when is_integer(duration) do
    days = div(duration, @convert_map[:days])
    hours = div(rem(duration, @convert_map[:days]), @convert_map[:hours])
    minutes = div(rem(duration, @convert_map[:hours]), @convert_map[:minutes])

    formatted =
      [
        if(days > 0, do: "#{days}d"),
        if(hours > 0, do: "#{hours}h"),
        if(minutes > 0, do: "#{minutes}m")
      ]
      |> Enum.reject(fn x -> is_nil(x) end)
      |> Enum.join(" ")

    case formatted do
      "" -> "0"
      _ -> formatted
    end
  end
end
