defmodule IrcBotWeb.ChannelLive do
  @moduledoc """
  Per-channel message feed with real-time updates.
  """

  use IrcBotWeb, :live_view

  import IrcBotWeb.IrcComponents

  alias IrcBot.Plugins.Karma.Store

  @max_messages 100

  @impl true
  def mount(%{"channel" => channel}, _session, socket) do
    channel = "#" <> channel

    if connected?(socket) do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "irc:events")
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
    end

    web_nick = "web_" <> Base.encode16(:crypto.strong_rand_bytes(2), case: :lower)

    {:ok,
     assign(socket,
       page_title: channel,
       channel: channel,
       web_nick: web_nick,
       form: to_form(%{"text" => ""}),
       messages: IrcBot.IRC.MessageBuffer.recent_for_channel(channel, @max_messages),
       karma_leaders: Store.leaderboard(channel, 10)
     )}
  end

  @impl true
  def handle_event("send_message", %{"text" => text}, socket) do
    text = String.trim(text)

    if text != "" do
      %{channel: channel, web_nick: web_nick} = socket.assigns
      formatted = "[#{web_nick}] #{text}"

      IrcBot.IRC.Client.send_message(channel, formatted)

      message =
        IrcBot.IRC.Message.new(
          type: :privmsg,
          nick: web_nick,
          channel: channel,
          text: text
        )

      IrcBot.IRC.MessageBuffer.push(message)

      Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{
        event: :message,
        data: message
      })

      replies = IrcBot.Plugin.Registry.dispatch(message)

      for {reply_channel, reply_text} <- replies do
        IrcBot.IRC.Client.send_message(reply_channel, reply_text)

        reply =
          IrcBot.IRC.Message.new(
            type: :privmsg,
            nick: Application.get_env(:irc_bot, :irc, []) |> Keyword.get(:nick, "elixir_bot"),
            channel: reply_channel,
            text: reply_text
          )

        IrcBot.IRC.MessageBuffer.push(reply)

        Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{
          event: :message,
          data: reply
        })
      end
    end

    {:noreply, assign(socket, :form, to_form(%{"text" => ""}))}
  end

  @impl true
  def handle_info(%{event: :message, data: %{channel: channel} = message}, socket)
      when channel == socket.assigns.channel do
    messages =
      [message | socket.assigns.messages]
      |> Enum.take(@max_messages)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info(%{event: :karma_changed, channel: channel}, socket)
      when channel == socket.assigns.channel do
    {:noreply, assign(socket, :karma_leaders, Store.leaderboard(channel, 10))}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">{@channel}</h1>
          <.link navigate={~p"/"} class="btn btn-sm btn-outline">
            Back to Dashboard
          </.link>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2">
            <div class="card bg-base-200 shadow-lg">
              <div class="card-body">
                <h2 class="card-title">Messages</h2>
                <.message_feed
                  messages={@messages}
                  empty_text="No messages yet in this channel."
                />
                <.form for={@form} phx-submit="send_message" class="mt-4 flex gap-2">
                  <input
                    type="text"
                    name="text"
                    value={@form["text"].value}
                    placeholder={"Chat as #{@web_nick}..."}
                    class="input input-bordered input-sm flex-1"
                    autocomplete="off"
                  />
                  <button type="submit" class="btn btn-primary btn-sm">Send</button>
                </.form>
              </div>
            </div>
          </div>

          <div>
            <.karma_sidebar
              karma_leaders={@karma_leaders}
              title="Channel Karma"
              empty_text="No karma scores in this channel."
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
