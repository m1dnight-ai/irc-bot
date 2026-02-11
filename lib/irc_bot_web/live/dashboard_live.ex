defmodule IrcBotWeb.DashboardLive do
  @moduledoc """
  Main dashboard showing per-channel IRC message feed, karma, and URLs.
  """

  use IrcBotWeb, :live_view

  import IrcBotWeb.IrcComponents

  alias IrcBot.Plugins.Karma.Store, as: KarmaStore
  alias IrcBot.Plugins.UrlCounter.Store, as: UrlStore

  @max_messages 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "irc:events")
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "url:updates")
    end

    web_nick = "web_" <> Base.encode16(:crypto.strong_rand_bytes(2), case: :lower)
    channels = Application.get_env(:irc_bot, :irc, []) |> Keyword.get(:channels, [])
    selected = List.first(channels)

    {:ok,
     socket
     |> assign(
       page_title: "Dashboard",
       web_nick: web_nick,
       channels: channels,
       selected_channel: selected,
       form: to_form(%{"text" => ""}),
       connected_to_irc: false
     )
     |> load_channel_data(selected)}
  end

  @impl true
  def handle_event("select_channel", %{"channel" => channel}, socket) do
    if channel in socket.assigns.channels do
      {:noreply,
       socket
       |> assign(:selected_channel, channel)
       |> load_channel_data(channel)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", %{"text" => text}, socket) do
    text = String.trim(text)

    if text != "" do
      %{web_nick: web_nick, selected_channel: channel} = socket.assigns
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

      # Dispatch through plugin system so commands like ,echo work
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
      when channel == socket.assigns.selected_channel do
    messages =
      [message | socket.assigns.messages]
      |> Enum.take(@max_messages)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info(%{event: :connected}, socket) do
    {:noreply, assign(socket, :connected_to_irc, true)}
  end

  @impl true
  def handle_info(%{event: :disconnected}, socket) do
    {:noreply, assign(socket, :connected_to_irc, false)}
  end

  @impl true
  def handle_info(%{event: :karma_changed, channel: channel}, socket)
      when channel == socket.assigns.selected_channel do
    {:noreply, assign(socket, :karma_leaders, KarmaStore.leaderboard(channel, 5))}
  end

  @impl true
  def handle_info(%{event: :url_shared}, socket) do
    channel = socket.assigns.selected_channel

    {:noreply,
     assign(socket,
       recent_urls: UrlStore.recent_urls_for_channel(channel, 5),
       top_domains: UrlStore.top_domains_for_channel(channel, 5)
     )}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp load_channel_data(socket, nil), do: assign(socket, messages: [], karma_leaders: [], recent_urls: [], top_domains: [])

  defp load_channel_data(socket, channel) do
    assign(socket,
      messages: IrcBot.IRC.MessageBuffer.recent_for_channel(channel, @max_messages),
      karma_leaders: KarmaStore.leaderboard(channel, 5),
      recent_urls: UrlStore.recent_urls_for_channel(channel, 5),
      top_domains: UrlStore.top_domains_for_channel(channel, 5)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6 pb-16">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">IRC Bot Dashboard</h1>
          <div class={[
            "badge badge-lg",
            @connected_to_irc && "badge-success",
            !@connected_to_irc && "badge-error"
          ]}>
            {if @connected_to_irc, do: "Connected", else: "Disconnected"}
          </div>
        </div>

        <div role="tablist" class="tabs tabs-bordered">
          <button
            :for={ch <- @channels}
            role="tab"
            phx-click="select_channel"
            phx-value-channel={ch}
            class={["tab", ch == @selected_channel && "tab-active"]}
          >
            {ch}
          </button>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Message Feed --%>
          <div class="lg:col-span-2">
            <div class="card bg-base-200 shadow-lg">
              <div class="card-body">
                <h2 class="card-title">{@selected_channel}</h2>
                <.message_feed
                  messages={@messages}
                  empty_text="No messages yet in this channel."
                />
              </div>
            </div>
          </div>

          <%!-- Sidebar --%>
          <div>
            <.karma_sidebar
              karma_leaders={@karma_leaders}
              title="Channel Karma"
              empty_text="No karma scores in this channel."
              show_link
            />

            <div class="card bg-base-200 shadow-lg mt-4">
              <div class="card-body">
                <h2 class="card-title">Recent URLs</h2>
                <div :if={@recent_urls == []} class="text-base-content/50 italic">
                  No URLs shared yet.
                </div>
                <div class="space-y-2">
                  <div :for={entry <- @recent_urls} class="truncate">
                    <span class="font-mono text-sm" title={entry.url}>{entry.url}</span>
                  </div>
                </div>
                <div :if={@top_domains != []} class="mt-2 pt-2 border-t border-base-content/10">
                  <h3 class="text-sm font-semibold mb-1">Top Domains</h3>
                  <div class="space-y-1">
                    <div
                      :for={{domain, count} <- @top_domains}
                      class="flex justify-between items-center text-sm"
                    >
                      <span class="font-mono">{domain}</span>
                      <span class="badge badge-sm badge-primary">{count}</span>
                    </div>
                  </div>
                </div>
                <div class="card-actions justify-end mt-2">
                  <.link navigate={~p"/urls"} class="btn btn-sm btn-outline">
                    View All URLs
                  </.link>
                </div>
              </div>
            </div>

            <div class="card bg-base-200 shadow-lg mt-4">
              <div class="card-body">
                <h2 class="card-title">Plugins</h2>
                <div class="space-y-1">
                  <div
                    :for={plugin <- IrcBot.Plugin.Registry.list_plugins()}
                    class="flex justify-between items-center"
                  >
                    <span class="font-medium">{plugin.name}</span>
                    <span class="text-sm text-base-content/60">{plugin.description}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="fixed bottom-0 left-0 right-0 bg-base-300 border-t border-base-content/10 p-3">
        <.form for={@form} phx-submit="send_message" class="max-w-4xl mx-auto flex gap-2 items-center">
          <span class="text-sm font-semibold text-base-content/60">{@selected_channel}</span>
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
    </Layouts.app>
    """
  end
end
