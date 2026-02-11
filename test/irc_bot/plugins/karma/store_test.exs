defmodule IrcBot.Plugins.Karma.StoreTest do
  use IrcBot.DataCase, async: false

  alias IrcBot.Plugins.Karma.Store

  describe "increment/2" do
    test "creates entry with score 1 for new user" do
      {:ok, entry} = Store.increment("alice", "#test")
      assert entry.score == 1
    end

    test "increments existing user's score" do
      Store.increment("alice", "#test")
      {:ok, entry} = Store.increment("alice", "#test")
      assert entry.score == 2
    end
  end

  describe "decrement/2" do
    test "creates entry with score -1 for new user" do
      {:ok, entry} = Store.decrement("alice", "#test")
      assert entry.score == -1
    end

    test "decrements existing user's score" do
      Store.increment("alice", "#test")
      {:ok, entry} = Store.decrement("alice", "#test")
      assert entry.score == 0
    end
  end

  describe "get_score/2" do
    test "returns 0 for unknown user" do
      assert 0 = Store.get_score("nobody", "#test")
    end

    test "returns current score" do
      Store.increment("alice", "#test")
      Store.increment("alice", "#test")
      assert 2 = Store.get_score("alice", "#test")
    end

    test "scores are channel-scoped" do
      Store.increment("alice", "#test")
      assert 0 = Store.get_score("alice", "#other")
    end
  end

  describe "leaderboard/2" do
    test "returns empty list when no scores" do
      assert [] = Store.leaderboard("#test")
    end

    test "returns users ordered by score descending" do
      Store.increment("alice", "#test")
      Store.increment("alice", "#test")
      Store.increment("bob", "#test")
      Store.increment("bob", "#test")
      Store.increment("bob", "#test")

      board = Store.leaderboard("#test")
      assert [{"bob", 3}, {"alice", 2}] = board
    end

    test "respects limit" do
      Store.increment("alice", "#test")
      Store.increment("bob", "#test")
      Store.increment("charlie", "#test")

      board = Store.leaderboard("#test", 2)
      assert length(board) == 2
    end
  end

  describe "global_leaderboard/1" do
    test "aggregates scores across channels" do
      Store.increment("alice", "#test")
      Store.increment("alice", "#dev")

      board = Store.global_leaderboard()
      assert [{"alice", 2}] = board
    end
  end
end
