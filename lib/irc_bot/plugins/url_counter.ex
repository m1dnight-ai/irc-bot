defmodule IrcBot.Plugins.UrlCounter do
  @moduledoc """
  URL counter plugin for the IRC bot.

  Tracks URLs shared in IRC channels, storing them in the database.
  Broadcasts updates via PubSub for real-time dashboard updates.

  Any message containing an http or https URL will be recorded.
  """

  @behaviour IrcBot.Plugin

  alias IrcBot.IRC.Message
  alias IrcBot.Plugins.UrlCounter.{Parser, Store}

  @impl true
  @spec name() :: String.t()
  def name, do: "url_counter"

  @impl true
  @spec description() :: String.t()
  def description, do: "Track URLs shared in chat"

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts), do: {:ok, %{}}

  @impl true
  @spec handles?(Message.t()) :: boolean()
  def handles?(%{type: :privmsg, text: text}) do
    Parser.extract_urls(text) != []
  end

  def handles?(_), do: false

  @impl true
  @spec handle_message(Message.t(), map()) :: {:noreply, map()}
  def handle_message(%{nick: nick, channel: channel, text: text}, state) do
    urls = Parser.extract_urls(text)

    for url <- urls do
      domain = Parser.extract_domain(url)

      if domain do
        Store.record_url(url, domain, nick, channel)
        broadcast_url_update(url, domain, nick, channel)
      end
    end

    {:noreply, state}
  end

  defp broadcast_url_update(url, domain, nick, channel) do
    Phoenix.PubSub.broadcast(IrcBot.PubSub, "url:updates", %{
      event: :url_shared,
      url: url,
      domain: domain,
      nick: nick,
      channel: channel
    })
  end
end
