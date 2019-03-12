# Donos

Bot for anonymous chatting in telegram

## Run in dev

- create bot in [@BotFather](t.me/botfather)
- set token from BotFather in `config/config.dev.ex` `:nadia.token`
- (optional) create channel for history
- (optional) set channel for history into `:donos.history_channel` (@name if it is public, it's id if it is private (it's hard to get id for private channel))
- install deps: `mix deps.get`
- run repl: `iex -S mix`
- on code change run `recompile` command
