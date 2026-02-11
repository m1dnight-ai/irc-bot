# IRC Bot

A modular IRC bot built with Elixir and Phoenix LiveView, featuring a plugin system, karma tracking, and a real-time web dashboard.

## Features

- **Plugin System** — Simple behaviour-based plugin architecture. Drop in new plugins with minimal boilerplate.
- **Karma Plugin** — Track karma with `user++` / `user--`, query with `!karma user`, leaderboard with `!karma`.
- **Real-time Web Dashboard** — Phoenix LiveView dashboard showing live IRC messages and karma leaderboard.
- **SQLite Storage** — Lightweight, zero-config persistence via `ecto_sqlite3`.
- **Local IRC Server** — Bundled ngircd config for easy local development/testing.

## Prerequisites

- Erlang/OTP 27+
- Elixir 1.18+
- ngircd (for local testing)

If you use [mise](https://mise.jdx.dev), the project is configured with the correct versions.

## Quick Start

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create && mix ecto.migrate

# Start a local IRC server (in a separate terminal)
./scripts/start_irc.sh

# Start the bot + web dashboard
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000) for the web dashboard.

Connect an IRC client to `localhost:6667`, join `#general`, and try:

```
alice++       → Gives alice karma
alice--       → Takes alice karma
!karma alice  → Shows alice's karma score
!karma        → Shows the leaderboard
```

## Architecture

```
lib/
├── irc_bot/
│   ├── irc/
│   │   ├── client.ex           # ExIRC GenServer wrapper
│   │   ├── client_behaviour.ex # Behaviour for mocking
│   │   └── message.ex          # Normalized message struct
│   ├── plugin/
│   │   └── registry.ex         # Plugin dispatch hub
│   ├── plugins/
│   │   ├── karma.ex            # Karma plugin
│   │   └── karma/
│   │       ├── parser.ex       # Karma command parser
│   │       ├── schema.ex       # Ecto schema
│   │       └── store.ex        # Database operations
│   ├── plugin.ex               # Plugin behaviour
│   └── application.ex
└── irc_bot_web/
    └── live/
        ├── dashboard_live.ex   # Main dashboard
        ├── karma_live.ex       # Karma leaderboard
        └── channel_live.ex     # Per-channel view
```

## Writing a Plugin

Create a module implementing the `IrcBot.Plugin` behaviour:

```elixir
defmodule IrcBot.Plugins.Hello do
  @behaviour IrcBot.Plugin

  @impl true
  def name, do: "hello"

  @impl true
  def description, do: "Responds to !hello"

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handles?(%{text: "!hello" <> _}), do: true
  def handles?(_), do: false

  @impl true
  def handle_message(%{nick: nick, channel: channel}, state) do
    {:reply, [{channel, "Hello, #{nick}!"}], state}
  end
end
```

Then add it to your config:

```elixir
# config/config.exs
config :irc_bot,
  plugins: [IrcBot.Plugins.Karma, IrcBot.Plugins.Hello]
```

### Plugin Callbacks

| Callback | Purpose |
|---|---|
| `name/0` | Unique plugin name |
| `description/0` | Human-readable description |
| `init/1` | Initialize plugin state |
| `handles?/1` | Return true if this plugin should handle the message |
| `handle_message/2` | Process the message, return `{:reply, replies, state}` or `{:noreply, state}` |

## Configuration

IRC connection settings in `config/dev.exs`:

```elixir
config :irc_bot, :irc,
  host: "localhost",
  port: 6667,
  nick: "elixir_bot",
  channels: ["#general"]
```

## Testing

```bash
mix test
```

## Web Routes

| Path | Description |
|---|---|
| `/` | Main dashboard with live message feed and karma sidebar |
| `/karma` | Full karma leaderboard |
| `/channels/:channel` | Per-channel message feed and karma |
# irc-bot
