defmodule IrcBotWeb.PageController do
  use IrcBotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
