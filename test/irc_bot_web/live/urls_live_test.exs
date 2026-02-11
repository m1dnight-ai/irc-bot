defmodule IrcBotWeb.UrlsLiveTest do
  use IrcBotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias IrcBot.Plugins.UrlCounter.Store

  test "renders URLs page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/urls")

    assert html =~ "URLs"
    assert html =~ "Back to Dashboard"
  end

  test "shows empty state when no URLs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/urls")
    assert html =~ "No URLs shared yet"
  end

  test "displays URL entries", %{conn: conn} do
    Store.record_url("https://example.com/page", "example.com", "alice", "#test")
    Store.record_url("https://other.com", "other.com", "bob", "#dev")

    {:ok, _view, html} = live(conn, "/urls")

    assert html =~ "example.com/page"
    assert html =~ "other.com"
    assert html =~ "alice"
    assert html =~ "bob"
  end

  test "displays top domains", %{conn: conn} do
    Store.record_url("https://example.com/1", "example.com", "alice", "#test")
    Store.record_url("https://example.com/2", "example.com", "bob", "#test")

    {:ok, _view, html} = live(conn, "/urls")

    assert html =~ "Top Domains"
    assert html =~ "example.com"
  end

  test "updates on url_shared broadcast", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/urls")

    Store.record_url("https://new-url.com", "new-url.com", "charlie", "#test")

    Phoenix.PubSub.broadcast(IrcBot.PubSub, "url:updates", %{
      event: :url_shared,
      url: "https://new-url.com",
      domain: "new-url.com",
      nick: "charlie",
      channel: "#test"
    })

    html = render(view)
    assert html =~ "new-url.com"
  end
end
