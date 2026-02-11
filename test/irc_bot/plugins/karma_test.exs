defmodule IrcBot.Plugins.KarmaTest do
  use IrcBot.DataCase, async: false

  alias IrcBot.IRC.Message
  alias IrcBot.Plugins.Karma

  setup do
    {:ok, state} = Karma.init([])
    %{state: state}
  end

  describe "handles?/1" do
    test "returns true for karma increment" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob++")
      assert Karma.handles?(msg)
    end

    test "returns true for karma decrement" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob--")
      assert Karma.handles?(msg)
    end

    test "returns true for karma query" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "!karma bob")
      assert Karma.handles?(msg)
    end

    test "returns true for leaderboard" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "!karma")
      assert Karma.handles?(msg)
    end

    test "returns false for regular messages" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "hello")
      refute Karma.handles?(msg)
    end

    test "returns false for non-privmsg" do
      msg = Message.new(type: :join, nick: "alice", channel: "#test", text: "")
      refute Karma.handles?(msg)
    end
  end

  describe "handle_message/2 - increment" do
    test "increments karma and returns reply", %{state: state} do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob++")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "bob now has 1 karma"
      assert reply =~ "+1 by alice"
    end

    test "prevents self-karma", %{state: state} do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "alice++")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "can't change your own karma"
    end
  end

  describe "handle_message/2 - decrement" do
    test "decrements karma and returns reply", %{state: state} do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob--")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "bob now has -1 karma"
      assert reply =~ "-1 by alice"
    end
  end

  describe "handle_message/2 - query" do
    test "returns karma score for user", %{state: state} do
      # Give bob some karma first
      inc = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob++")
      Karma.handle_message(inc, state)

      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "!karma bob")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "bob has 1 karma"
    end
  end

  describe "handle_message/2 - PubSub broadcasts" do
    test "broadcasts on increment", %{state: state} do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob++")
      Karma.handle_message(msg, state)

      assert_receive %{event: :karma_changed, username: "bob", channel: "#test"}
    end

    test "broadcasts on decrement", %{state: state} do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob--")
      Karma.handle_message(msg, state)

      assert_receive %{event: :karma_changed, username: "bob", channel: "#test"}
    end

    test "no broadcast on self-karma attempt", %{state: state} do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "alice++")
      Karma.handle_message(msg, state)

      refute_receive %{event: :karma_changed}
    end
  end

  describe "handle_message/2 - accumulation" do
    test "karma accumulates across multiple increments", %{state: state} do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "bob++")
      {:reply, _, state} = Karma.handle_message(msg, state)
      {:reply, _, state} = Karma.handle_message(msg, state)
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "bob now has 3 karma"
    end

    test "karma is scoped per-channel", %{state: state} do
      msg1 = Message.new(type: :privmsg, nick: "alice", channel: "#one", text: "bob++")
      msg2 = Message.new(type: :privmsg, nick: "alice", channel: "#two", text: "bob++")
      msg2b = Message.new(type: :privmsg, nick: "alice", channel: "#two", text: "bob++")

      Karma.handle_message(msg1, state)
      Karma.handle_message(msg2, state)
      Karma.handle_message(msg2b, state)

      query1 = Message.new(type: :privmsg, nick: "alice", channel: "#one", text: "!karma bob")
      {:reply, [{_ch, reply1}], _} = Karma.handle_message(query1, state)
      assert reply1 =~ "bob has 1 karma"

      query2 = Message.new(type: :privmsg, nick: "alice", channel: "#two", text: "!karma bob")
      {:reply, [{_ch, reply2}], _} = Karma.handle_message(query2, state)
      assert reply2 =~ "bob has 2 karma"
    end
  end

  describe "handle_message/2 - leaderboard" do
    test "shows leaderboard", %{state: state} do
      inc = Message.new(type: :privmsg, nick: "bob", channel: "#test", text: "alice++")
      Karma.handle_message(inc, state)

      msg = Message.new(type: :privmsg, nick: "bob", channel: "#test", text: "!karma")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "leaderboard"
      assert reply =~ "alice"
    end

    test "shows empty message when no karma", %{state: state} do
      msg = Message.new(type: :privmsg, nick: "bob", channel: "#test", text: "!karma")
      {:reply, [{_ch, reply}], _state} = Karma.handle_message(msg, state)
      assert reply =~ "No karma scores yet!"
    end
  end
end
