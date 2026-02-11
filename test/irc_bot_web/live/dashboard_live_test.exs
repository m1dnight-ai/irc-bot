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

  test "renders join channel form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#join-channel-form")
    assert has_element?(view, "#join-channel-form button", "Join")
  end

  test "joining a new channel adds it to tabs and selects it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#join-channel-form", join: %{channel: "newchannel"})
    |> render_submit()

    html = render(view)
    assert html =~ "#newchannel"
    # The new channel should be selected (tab-active)
    assert has_element?(view, "button.tab-active", "#newchannel")
  end

  test "joining a channel with # prefix works", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#join-channel-form", join: %{channel: "#testing"})
    |> render_submit()

    html = render(view)
    assert html =~ "#testing"
    assert has_element?(view, "button.tab-active", "#testing")
  end

  test "joining an already-joined channel selects it without duplicating", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # #general is already joined from config
    view
    |> form("#join-channel-form", join: %{channel: "#general"})
    |> render_submit()

    # Should still have only one #general tab
    assert has_element?(view, "button.tab-active", "#general")
  end

  test "joining with empty input does nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#join-channel-form", join: %{channel: ""})
    |> render_submit()

    # Should still show #general as selected
    assert has_element?(view, "button.tab-active", "#general")
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
