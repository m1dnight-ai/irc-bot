defmodule IrcBot.Plugins.Echo do
  @moduledoc """
  Echo plugin. Repeats a message back to the channel, prefixed with the sender's nick.

  Usage: `,echo some message`
  Bot replies: `sender: some message`
  """

  @behaviour IrcBot.Plugin

  alias IrcBot.IRC.Message

  @impl true
  @spec name() :: String.t()
  def name, do: "echo"

  @impl true
  @spec description() :: String.t()
  def description, do: "Echoes messages back with ,echo"

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts), do: {:ok, %{}}

  @impl true
  @spec handles?(Message.t()) :: boolean()
  def handles?(%{type: :privmsg, text: ",echo " <> _}), do: true
  def handles?(_), do: false

  @impl true
  @spec handle_message(Message.t(), map()) :: {:reply, [{String.t(), String.t()}], map()}
  def handle_message(%{nick: nick, channel: channel, text: ",echo " <> text}, state) do
    {:reply, [{channel, "#{nick}: #{text}"}], state}
  end
end
