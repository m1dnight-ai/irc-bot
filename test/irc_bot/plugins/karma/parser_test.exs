defmodule IrcBot.Plugins.Karma.ParserTest do
  use ExUnit.Case, async: true

  alias IrcBot.Plugins.Karma.Parser

  describe "parse/1" do
    test "parses increment" do
      assert {:increment, "alice"} = Parser.parse("alice++")
    end

    test "parses decrement" do
      assert {:decrement, "bob"} = Parser.parse("bob--")
    end

    test "parses increment with trailing text" do
      assert {:increment, "alice"} = Parser.parse("alice++ nice work")
    end

    test "downcases usernames" do
      assert {:increment, "alice"} = Parser.parse("Alice++")
      assert {:decrement, "bob"} = Parser.parse("BOB--")
    end

    test "parses karma query" do
      assert {:query, "alice"} = Parser.parse("!karma alice")
    end

    test "parses karma query with case insensitivity" do
      assert {:query, "alice"} = Parser.parse("!karma Alice")
    end

    test "parses leaderboard command" do
      assert :leaderboard = Parser.parse("!karma")
    end

    test "parses leaderboard with trailing whitespace" do
      assert :leaderboard = Parser.parse("!karma  ")
    end

    test "returns :ignore for non-karma messages" do
      assert :ignore = Parser.parse("hello world")
      assert :ignore = Parser.parse("++")
      assert :ignore = Parser.parse("not a command")
    end
  end
end
