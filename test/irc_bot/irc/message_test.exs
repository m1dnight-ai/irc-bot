defmodule IrcBot.IRC.MessageTest do
  use ExUnit.Case, async: true

  alias IrcBot.IRC.Message

  describe "new/1" do
    test "creates a message with all fields" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "hello")

      assert msg.type == :privmsg
      assert msg.nick == "alice"
      assert msg.channel == "#test"
      assert msg.text == "hello"
      assert %DateTime{} = msg.timestamp
    end

    test "auto-generates UTC timestamp" do
      before = DateTime.utc_now()
      msg = Message.new(type: :privmsg, text: "hello")
      after_ts = DateTime.utc_now()

      assert DateTime.compare(msg.timestamp, before) in [:gt, :eq]
      assert DateTime.compare(msg.timestamp, after_ts) in [:lt, :eq]
    end

    test "allows overriding timestamp" do
      ts = ~U[2025-01-01 12:00:00Z]
      msg = Message.new(type: :privmsg, text: "hello", timestamp: ts)

      assert msg.timestamp == ts
    end

    test "defaults nick and channel to nil" do
      msg = Message.new(type: :quit, text: "goodbye")

      assert msg.nick == nil
      assert msg.channel == nil
    end

    test "supports all message types" do
      for type <- [:privmsg, :notice, :join, :part, :quit, :kick, :unknown] do
        msg = Message.new(type: type, text: "test")
        assert msg.type == type
      end
    end

    test "raises on missing required fields" do
      assert_raise ArgumentError, fn -> Message.new(type: :privmsg) end
      assert_raise ArgumentError, fn -> Message.new(text: "hello") end
    end
  end
end
