defmodule IrcBot.TestPlugin do
  @moduledoc false
  @behaviour IrcBot.Plugin

  @impl true
  def name, do: "test_plugin"

  @impl true
  def description, do: "A plugin for testing"

  @impl true
  def init(_opts), do: {:ok, %{count: 0}}

  @impl true
  def handles?(%{text: "!test" <> _}), do: true
  def handles?(_), do: false

  @impl true
  def handle_message(%{nick: nick, channel: channel}, state) do
    new_count = state.count + 1
    {:reply, [{channel, "Hello #{nick}! (count: #{new_count})"}], %{state | count: new_count}}
  end
end
