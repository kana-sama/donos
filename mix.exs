defmodule Donos.MixProject do
  use Mix.Project

  def project do
    [
      app: :donos,
      version: "1.0.0",
      elixir: "~> 1.8",
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
      {:nadia, "~> 0.4.4"},
      {:faker, "~> 0.12"}
    ]
  end
end
