defmodule IrcBot.Plugins.Karma.Store do
  @moduledoc """
  Database operations for karma scores.

  All operations are scoped to a channel, allowing per-channel karma tracking.
  """

  import Ecto.Query

  alias IrcBot.Plugins.Karma.Schema
  alias IrcBot.Repo

  @doc "Increments a user's karma in the given channel by 1."
  @spec increment(String.t(), String.t()) :: {:ok, Schema.t()}
  def increment(username, channel) do
    change_score(username, channel, 1)
  end

  @doc "Decrements a user's karma in the given channel by 1."
  @spec decrement(String.t(), String.t()) :: {:ok, Schema.t()}
  def decrement(username, channel) do
    change_score(username, channel, -1)
  end

  @doc "Gets the current karma score for a user in a channel."
  @spec get_score(String.t(), String.t()) :: integer()
  def get_score(username, channel) do
    Schema
    |> where(username: ^username, channel: ^channel)
    |> select([k], k.score)
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc "Returns the top `limit` users by karma in a channel."
  @spec leaderboard(String.t(), pos_integer()) :: [{String.t(), integer()}]
  def leaderboard(channel, limit \\ 5) do
    Schema
    |> where(channel: ^channel)
    |> order_by([k], desc: k.score)
    |> limit(^limit)
    |> select([k], {k.username, k.score})
    |> Repo.all()
  end

  @doc "Returns the top `limit` users by karma across all channels."
  @spec global_leaderboard(pos_integer()) :: [{String.t(), integer()}]
  def global_leaderboard(limit \\ 10) do
    Schema
    |> group_by([k], k.username)
    |> order_by([k], desc: sum(k.score))
    |> limit(^limit)
    |> select([k], {k.username, sum(k.score)})
    |> Repo.all()
  end

  defp change_score(username, channel, delta) do
    Repo.insert(
      %Schema{username: username, score: delta, channel: channel},
      on_conflict: [inc: [score: delta]],
      conflict_target: [:username, :channel],
      returning: true
    )
  end
end
