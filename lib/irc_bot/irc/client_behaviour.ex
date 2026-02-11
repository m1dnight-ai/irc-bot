defmodule IrcBot.IRC.ClientBehaviour do
  @moduledoc """
  Behaviour for the IRC client, enabling test mocking.
  """

  @callback send_message(channel :: String.t(), text :: String.t()) :: :ok
  @callback join_channel(channel :: String.t()) :: :ok
end
