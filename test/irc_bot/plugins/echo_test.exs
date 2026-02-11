defmodule IrcBot.Plugins.EchoTest do
  use ExUnit.Case, async: true

  alias IrcBot.IRC.Message
  alias IrcBot.Plugins.Echo

  setup do
    {:ok, state} = Echo.init([])
    %{state: state}
  end

  describe "name/0 and description/0" do
    test "returns plugin info" do
      assert Echo.name() == "echo"
      assert Echo.description() =~ "echo"
    end
  end

  describe "handles?/1" do
    test "matches ,echo messages" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: ",echo hello")
      assert Echo.handles?(msg)
    end

    test "rejects messages without ,echo prefix" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "hello")
      refute Echo.handles?(msg)
    end

    test "rejects bare ,echo with no text" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: ",echo")
      refute Echo.handles?(msg)
    end

    test "rejects non-privmsg" do
      msg = Message.new(type: :join, nick: "alice", channel: "#test", text: ",echo hi")
      refute Echo.handles?(msg)
    end
  end

  describe "handle_message/2" do
    test "echoes back with sender prefix", %{state: state} do
      msg =
        Message.new(type: :privmsg, nick: "alice", channel: "#test", text: ",echo hello world")

      assert {:reply, [{"#test", "alice: hello world"}], ^state} = Echo.handle_message(msg, state)
    end

    test "preserves extra whitespace in echo text", %{state: state} do
      msg =
        Message.new(type: :privmsg, nick: "bob", channel: "#dev", text: ",echo   spaced  out  ")

      assert {:reply, [{"#dev", "bob:   spaced  out  "}], ^state} =
               Echo.handle_message(msg, state)
    end
  end
end
