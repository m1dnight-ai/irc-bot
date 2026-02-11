import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :irc_bot, IrcBot.Repo,
  database: Path.expand("../irc_bot_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :irc_bot, IrcBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7gBgjQrS+uGdI+tgzI2EQJjXDwN1rvSEkLsfd0p2zNEMmCPdCbUhqXqVo364KtAj",
  server: false

# IRC config for tests (client doesn't start, but dashboard reads channels)
config :irc_bot, :irc, channels: ["#general"]

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
