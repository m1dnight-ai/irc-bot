defmodule IrcBotWeb.ThemeToggleTest do
  use IrcBotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "theme toggle is rendered on dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # Four theme buttons: system, light, pink, dark
    assert has_element?(view, "button[data-phx-theme=system]")
    assert has_element?(view, "button[data-phx-theme=light]")
    assert has_element?(view, "button[data-phx-theme=pink]")
    assert has_element?(view, "button[data-phx-theme=dark]")
  end

  test "theme toggle is rendered on karma page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/karma")

    assert has_element?(view, "button[data-phx-theme=system]")
    assert has_element?(view, "button[data-phx-theme=light]")
    assert has_element?(view, "button[data-phx-theme=pink]")
    assert has_element?(view, "button[data-phx-theme=dark]")
  end

  test "theme toggle is rendered on urls page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/urls")

    assert has_element?(view, "button[data-phx-theme=system]")
    assert has_element?(view, "button[data-phx-theme=light]")
    assert has_element?(view, "button[data-phx-theme=pink]")
    assert has_element?(view, "button[data-phx-theme=dark]")
  end

  test "root layout includes theme-aware body classes", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)

    assert html =~ ~s(class="bg-base-100 text-base-content")
  end

  test "root layout includes theme initialization script", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)

    assert html =~ "phx:set-theme"
    assert html =~ "localStorage"
    assert html =~ "data-theme"
  end

  test "pink theme is the default when no preference is saved", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)

    assert html =~ ~s(|| "pink")
  end
end
