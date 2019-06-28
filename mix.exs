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
      {:exmoji, github: "mroth/exmoji"},
      {:faker, "~> 0.12.0"},
      {:nadia,
       git: "https://github.com/kana-sama/nadia.git",
       ref: "498a8241936fdc7a810f67d95cfe5d8f36ee3bb6"}
    ]
  end
end
