defmodule IrcBot.IRC.MessageBufferTest do
  use ExUnit.Case, async: false

  alias IrcBot.IRC.{Message, MessageBuffer}

  setup do
    # Terminate the app-supervised buffer and restart it fresh
    Supervisor.terminate_child(IrcBot.Supervisor, MessageBuffer)
    Supervisor.restart_child(IrcBot.Supervisor, MessageBuffer)

    on_exit(fn ->
      # Ensure buffer is running for subsequent test modules
      unless Process.whereis(MessageBuffer) do
        Supervisor.restart_child(IrcBot.Supervisor, MessageBuffer)
      end
    end)

    :ok
  end

  describe "push/1 and recent/1" do
    test "returns messages in reverse chronological order" do
      for i <- 1..3 do
        MessageBuffer.push(Message.new(type: :privmsg, text: "msg#{i}"))
      end

      messages = MessageBuffer.recent()
      assert [%{text: "msg3"}, %{text: "msg2"}, %{text: "msg1"}] = messages
    end

    test "respects limit parameter" do
      for i <- 1..5 do
        MessageBuffer.push(Message.new(type: :privmsg, text: "msg#{i}"))
      end

      messages = MessageBuffer.recent(2)
      assert length(messages) == 2
      assert [%{text: "msg5"}, %{text: "msg4"}] = messages
    end

    test "empty buffer returns empty list" do
      assert [] = MessageBuffer.recent()
    end

    test "buffer overflow evicts oldest messages" do
      for i <- 1..205 do
        MessageBuffer.push(Message.new(type: :privmsg, text: "msg#{i}"))
      end

      messages = MessageBuffer.recent(300)
      assert length(messages) == 200
      assert hd(messages).text == "msg205"
      assert List.last(messages).text == "msg6"
    end
  end

  describe "recent_for_channel/2" do
    test "filters by channel" do
      MessageBuffer.push(Message.new(type: :privmsg, channel: "#a", text: "hello"))
      MessageBuffer.push(Message.new(type: :privmsg, channel: "#b", text: "world"))
      MessageBuffer.push(Message.new(type: :privmsg, channel: "#a", text: "foo"))

      messages = MessageBuffer.recent_for_channel("#a")
      assert length(messages) == 2
      assert Enum.all?(messages, &(&1.channel == "#a"))
    end

    test "unknown channel returns empty list" do
      MessageBuffer.push(Message.new(type: :privmsg, channel: "#a", text: "hello"))

      assert [] = MessageBuffer.recent_for_channel("#nonexistent")
    end

    test "respects channel limit" do
      for i <- 1..5 do
        MessageBuffer.push(Message.new(type: :privmsg, channel: "#a", text: "msg#{i}"))
      end

      messages = MessageBuffer.recent_for_channel("#a", 2)
      assert length(messages) == 2
      assert [%{text: "msg5"}, %{text: "msg4"}] = messages
    end
  end
end
