use Mix.Config

config :donos,
  show_own_messages?: false,
  session_life: 1000 * 60 * 30

config :nadia,
  token: System.get_env("DONOS_TOKEN")
