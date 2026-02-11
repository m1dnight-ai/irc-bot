defmodule IrcBot.Plugins.Karma.Parser do
  @moduledoc """
  Parses IRC messages for karma commands.

  Supports:
  - `user++` / `user--` — increment/decrement karma
  - `!karma user` — check a user's karma
  - `!karma` — show the leaderboard
  """

  @type command ::
          {:increment, String.t()}
          | {:decrement, String.t()}
          | {:query, String.t()}
          | :leaderboard
          | :ignore

  @karma_change_regex ~r/^(\w+)(\+\+|--)(?:\s|$)/
  @karma_query_regex ~r/^!karma\s+(\w+)\s*$/
  @karma_leaderboard_regex ~r/^!karma\s*$/

  @doc "Parses a message text into a karma command."
  @spec parse(String.t()) :: command()
  def parse(text) do
    text = String.trim(text)

    cond do
      match = Regex.run(@karma_leaderboard_regex, text) ->
        parse_leaderboard(match)

      match = Regex.run(@karma_query_regex, text) ->
        parse_query(match)

      match = Regex.run(@karma_change_regex, text) ->
        parse_change(match)

      true ->
        :ignore
    end
  end

  defp parse_leaderboard([_]), do: :leaderboard

  defp parse_query([_, username]), do: {:query, String.downcase(username)}

  defp parse_change([_, username, "++"]), do: {:increment, String.downcase(username)}
  defp parse_change([_, username, "--"]), do: {:decrement, String.downcase(username)}
end
