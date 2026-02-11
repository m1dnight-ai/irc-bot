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

    {:ok,
     assign(socket,
       page_title: channel,
       channel: channel,
       messages: IrcBot.IRC.MessageBuffer.recent_for_channel(channel, @max_messages),
       karma_leaders: Store.leaderboard(channel, 10)
     )}
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
