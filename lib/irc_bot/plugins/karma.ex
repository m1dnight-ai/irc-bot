defmodule IrcBot.Plugins.Karma do
  @moduledoc """
  Karma plugin for the IRC bot.

  Allows users to give or take karma from other users using `user++` and `user--`.
  Prevents self-karma changes. Broadcasts updates via PubSub.

  Commands:
  - `user++` — give karma
  - `user--` — take karma
  - `!karma user` — check karma
  - `!karma` — show leaderboard
  """

  @behaviour IrcBot.Plugin

  alias IrcBot.IRC.Message
  alias IrcBot.Plugins.Karma.{Parser, Store}

  @impl true
  @spec name() :: String.t()
  def name, do: "karma"

  @impl true
  @spec description() :: String.t()
  def description, do: "Track karma scores with user++ and user--"

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts), do: {:ok, %{}}

  @impl true
  @spec handles?(Message.t()) :: boolean()
  def handles?(%{type: :privmsg, text: text}) do
    Parser.parse(text) != :ignore
  end

  def handles?(_), do: false

  @impl true
  @spec handle_message(Message.t(), map()) ::
          {:reply, [{String.t(), String.t()}], map()} | {:noreply, map()}
  def handle_message(%{nick: nick, channel: channel, text: text}, state) do
    case Parser.parse(text) do
      {:increment, target} ->
        handle_change(nick, target, channel, :increment, state)

      {:decrement, target} ->
        handle_change(nick, target, channel, :decrement, state)

      {:query, target} ->
        handle_query(target, channel, state)

      :leaderboard ->
        handle_leaderboard(channel, state)

      :ignore ->
        {:noreply, state}
    end
  end

  defp handle_change(nick, target, channel, _action, state) when nick == target do
    {:reply, [{channel, "#{nick}: You can't change your own karma!"}], state}
  end

  defp handle_change(nick, target, channel, action, state) do
    apply_change(action, target, channel)
    score = Store.get_score(target, channel)
    broadcast_karma_update(target, score, channel)

    {:reply, [{channel, "#{target} now has #{score} karma (#{action_label(action)} by #{nick})"}],
     state}
  end

  defp handle_query(target, channel, state) do
    score = Store.get_score(target, channel)
    {:reply, [{channel, "#{target} has #{score} karma"}], state}
  end

  defp handle_leaderboard(channel, state) do
    entries = Store.leaderboard(channel)

    reply =
      if entries == [] do
        "No karma scores yet!"
      else
        header = "Karma leaderboard:"

        lines =
          entries
          |> Enum.with_index(1)
          |> Enum.map(fn {{user, score}, rank} -> "#{rank}. #{user}: #{score}" end)

        Enum.join([header | lines], " | ")
      end

    {:reply, [{channel, reply}], state}
  end

  defp apply_change(:increment, target, channel), do: Store.increment(target, channel)
  defp apply_change(:decrement, target, channel), do: Store.decrement(target, channel)

  defp action_label(:increment), do: "+1"
  defp action_label(:decrement), do: "-1"

  defp broadcast_karma_update(username, score, channel) do
    Phoenix.PubSub.broadcast(IrcBot.PubSub, "karma:updates", %{
      event: :karma_changed,
      username: username,
      score: score,
      channel: channel
    })
  end
end
