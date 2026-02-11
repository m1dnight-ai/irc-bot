defmodule IrcBotWeb.DashboardLiveTest do
  use IrcBotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders dashboard page", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "IRC Bot Dashboard"
    assert html =~ "#general"
    assert html =~ "Channel Karma"
    assert html =~ "Disconnected"
    assert has_element?(view, "a", "View Full Leaderboard")
  end

  test "receives and displays IRC messages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    message = %IrcBot.IRC.Message{
      type: :privmsg,
      nick: "testuser",
      channel: "#general",
      text: "Hello from test!",
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{event: :message, data: message})

    # Wait for the message to be processed
    html = render(view)
    assert html =~ "testuser"
    assert html =~ "Hello from test!"
  end

  test "updates karma leaderboard on changes", %{conn: conn} do
    # Create some karma data
    IrcBot.Plugins.Karma.Store.increment("testuser", "#general")

    {:ok, view, _html} = live(conn, "/")

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "karma:updates", %{
      event: :karma_changed,
      username: "testuser",
      score: 1,
      channel: "#general"
    })

    html = render(view)
    assert html =~ "testuser"
  end
end
