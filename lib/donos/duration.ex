defmodule Duration do
  @convert_map %{
    milliseconds: 1,
    seconds: 1 * 1000,
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
end
