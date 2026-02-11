defmodule IrcBot.Plugins.UrlCounterTest do
  use IrcBot.DataCase, async: false

  alias IrcBot.IRC.Message
  alias IrcBot.Plugins.UrlCounter

  setup do
    {:ok, state} = UrlCounter.init([])
    %{state: state}
  end

  describe "handles?/1" do
    test "returns true for message with URL" do
      msg =
        Message.new(
          type: :privmsg,
          nick: "alice",
          channel: "#test",
          text: "check https://example.com"
        )

      assert UrlCounter.handles?(msg)
    end

    test "returns false for message without URL" do
      msg = Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "hello world")
      refute UrlCounter.handles?(msg)
    end

    test "returns false for non-privmsg" do
      msg = Message.new(type: :join, nick: "alice", channel: "#test", text: "https://example.com")
      refute UrlCounter.handles?(msg)
    end
  end

  describe "handle_message/2" do
    test "records URL and returns noreply", %{state: state} do
      msg =
        Message.new(
          type: :privmsg,
          nick: "alice",
          channel: "#test",
          text: "see https://example.com"
        )

      assert {:noreply, ^state} = UrlCounter.handle_message(msg, state)

      urls = IrcBot.Plugins.UrlCounter.Store.recent_urls()
      assert [%{url: "https://example.com", domain: "example.com", nick: "alice"}] = urls
    end

    test "records multiple URLs from one message", %{state: state} do
      msg =
        Message.new(
          type: :privmsg,
          nick: "alice",
          channel: "#test",
          text: "see https://foo.com and https://bar.com"
        )

      UrlCounter.handle_message(msg, state)

      urls = IrcBot.Plugins.UrlCounter.Store.recent_urls()
      assert length(urls) == 2
    end

    test "broadcasts url:updates on URL share", %{state: state} do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "url:updates")

      msg =
        Message.new(type: :privmsg, nick: "alice", channel: "#test", text: "https://example.com")

      UrlCounter.handle_message(msg, state)

      assert_receive %{event: :url_shared, url: "https://example.com", domain: "example.com"}
    end
  end
end
