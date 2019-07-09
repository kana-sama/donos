defmodule Donos.MixProject do
  use Mix.Project

  def project do
    [
      app: :donos,
      version: "2.0.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Donos.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.1"},
      {:postgrex, "~> 0.14.3"}
    ]
  end
end
