defmodule IrcBotWeb.KarmaLiveTest do
  use IrcBotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders karma leaderboard page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/karma")

    assert html =~ "Karma Leaderboard"
    assert html =~ "Back to Dashboard"
  end

  test "shows empty state when no karma", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/karma")
    assert html =~ "No karma scores yet"
  end

  test "displays karma entries", %{conn: conn} do
    IrcBot.Plugins.Karma.Store.increment("alice", "#test")
    IrcBot.Plugins.Karma.Store.increment("alice", "#test")
    IrcBot.Plugins.Karma.Store.increment("bob", "#test")

    {:ok, _view, html} = live(conn, "/karma")

    assert html =~ "alice"
    assert html =~ "bob"
  end

  test "updates on karma change broadcast", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/karma")

    IrcBot.Plugins.Karma.Store.increment("charlie", "#test")

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "karma:updates", %{
      event: :karma_changed,
      username: "charlie",
      score: 1,
      channel: "#test"
    })

    html = render(view)
    assert html =~ "charlie"
  end
end
