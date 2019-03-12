use Mix.Config

config :donos,
  session_lifetime: 1000 * 60 * 30,
  history_channel: System.get_env("DONOS_HISTORY")

config :nadia,
  token: System.get_env("DONOS_TOKEN")
