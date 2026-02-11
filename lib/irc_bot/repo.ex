defmodule IrcBot.Repo do
  use Ecto.Repo,
    otp_app: :irc_bot,
    adapter: Ecto.Adapters.SQLite3
end
