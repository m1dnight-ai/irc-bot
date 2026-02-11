defmodule IrcBot.Plugin do
  @moduledoc """
  Behaviour that all IRC bot plugins must implement.

  ## Example

      defmodule MyPlugin do
        @behaviour IrcBot.Plugin

        @impl true
        def name, do: "my_plugin"

        @impl true
        def description, do: "Does something useful"

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handles?(%{text: "!hello" <> _}), do: true
        def handles?(_), do: false

        @impl true
        def handle_message(%{nick: nick, channel: channel}, state) do
          {:reply, [{channel, "Hello, \#{nick}!"}], state}
        end
      end
  """

  alias IrcBot.IRC.Message

  @doc "Returns the plugin's unique name."
  @callback name() :: String.t()

  @doc "Returns a human-readable description."
  @callback description() :: String.t()

  @doc "Initializes plugin state. Called once at startup."
  @callback init(opts :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc "Returns true if this plugin should handle the given message."
  @callback handles?(message :: Message.t()) :: boolean()

  @doc """
  Handles a message.

  Returns:
  - `{:reply, [{channel, text}], new_state}` — send replies to channels
  - `{:noreply, new_state}` — no response needed
  """
  @callback handle_message(message :: Message.t(), state :: term()) ::
              {:reply, [{String.t(), String.t()}], term()}
              | {:noreply, term()}
end
