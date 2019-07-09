use Mix.Config

config :donos,
  ecto_repos: [Donos.Repo]

import_config("config.#{Mix.env()}.exs")
