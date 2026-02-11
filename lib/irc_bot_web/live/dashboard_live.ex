defmodule IrcBotWeb.DashboardLive do
  @moduledoc """
  Main dashboard showing live IRC message feed and mini karma leaderboard.
  """

  use IrcBotWeb, :live_view

  import IrcBotWeb.IrcComponents

  alias IrcBot.Plugins.Karma.Store

  @max_messages 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "irc:events")
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
    end

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       messages: IrcBot.IRC.MessageBuffer.recent(@max_messages),
       karma_leaders: Store.global_leaderboard(5),
       connected_to_irc: false
     )}
  end

  @impl true
  def handle_info(%{event: :message, data: message}, socket) do
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
  def handle_info(%{event: :karma_changed}, socket) do
    {:noreply, assign(socket, :karma_leaders, Store.global_leaderboard(5))}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
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

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Message Feed --%>
          <div class="lg:col-span-2">
            <div class="card bg-base-200 shadow-lg">
              <div class="card-body">
                <h2 class="card-title">Live Message Feed</h2>
                <.message_feed
                  messages={@messages}
                  empty_text="No messages yet. Connect to IRC to see live messages."
                />
              </div>
            </div>
          </div>

          <%!-- Karma Sidebar --%>
          <div>
            <.karma_sidebar karma_leaders={@karma_leaders} show_link />

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
    </Layouts.app>
    """
  end
end
