defmodule IrcBot.IRC.Message do
  @moduledoc """
  Normalized IRC message struct used throughout the bot.

  Provides a consistent format regardless of the raw IRC protocol details,
  making it easy for plugins to pattern-match on message properties.
  """

  @type message_type :: :privmsg | :notice | :join | :part | :quit | :kick | :unknown

  @type t :: %__MODULE__{
          type: message_type(),
          nick: String.t() | nil,
          channel: String.t() | nil,
          text: String.t(),
          timestamp: DateTime.t()
        }

  @enforce_keys [:type, :text]
  defstruct [:type, :nick, :channel, :text, :timestamp]

  @doc """
  Creates a new message with the current UTC timestamp.
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, Keyword.put_new(attrs, :timestamp, DateTime.utc_now()))
  end
end
