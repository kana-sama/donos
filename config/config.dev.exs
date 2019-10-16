use Mix.Config

config :donos,
  session_lifetime: 1000 * 60 * 30,
  history_channel: "@fwdonosdevhistory",
  blacklist: MapSet.new([])

config :nadia,
  token: "673233743:AAGpCTToTtiFAsWBlese1CrspcC1hlzg86s"
