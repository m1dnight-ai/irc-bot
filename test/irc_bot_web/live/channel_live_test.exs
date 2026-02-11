defmodule IrcBotWeb.ChannelLiveTest do
  use IrcBotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders channel page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/channels/general")

    assert html =~ "#general"
    assert html =~ "Channel Karma"
    assert html =~ "Back to Dashboard"
  end

  test "shows messages for the channel only", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/channels/general")

    # Message for this channel
    msg = %IrcBot.IRC.Message{
      type: :privmsg,
      nick: "alice",
      channel: "#general",
      text: "Hello general!",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{event: :message, data: msg})
    html = render(view)
    assert html =~ "Hello general!"

    # Message for other channel — should not appear
    other_msg = %IrcBot.IRC.Message{
      type: :privmsg,
      nick: "bob",
      channel: "#other",
      text: "Hello other!",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{event: :message, data: other_msg})
    html = render(view)
    refute html =~ "Hello other!"
  end
end
