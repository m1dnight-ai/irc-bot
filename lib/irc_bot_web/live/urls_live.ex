defmodule IrcBotWeb.UrlsLive do
  @moduledoc """
  Dashboard page showing recent URLs and top domains.
  """

  use IrcBotWeb, :live_view

  alias IrcBot.Plugins.UrlCounter.Store

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "url:updates")
    end

    {:ok,
     assign(socket,
       page_title: "URLs",
       recent_urls: Store.recent_urls(25),
       top_domains: Store.top_domains(10),
       total_count: Store.total_count()
     )}
  end

  @impl true
  def handle_info(%{event: :url_shared}, socket) do
    {:noreply,
     assign(socket,
       recent_urls: Store.recent_urls(25),
       top_domains: Store.top_domains(10),
       total_count: Store.total_count()
     )}
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
          <h1 class="text-2xl font-bold">URLs</h1>
          <div class="flex gap-2 items-center">
            <span class="badge badge-lg badge-info">{@total_count} total</span>
            <.link navigate={~p"/"} class="btn btn-sm btn-outline">
              Back to Dashboard
            </.link>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Recent URLs --%>
          <div class="lg:col-span-2">
            <div class="card bg-base-200 shadow-lg">
              <div class="card-body">
                <h2 class="card-title">Recent URLs</h2>
                <div :if={@recent_urls == []} class="text-base-content/50 italic text-center py-8">
                  No URLs shared yet.
                </div>
                <div class="overflow-x-auto">
                  <table :if={@recent_urls != []} class="table">
                    <thead>
                      <tr>
                        <th>URL</th>
                        <th>Shared by</th>
                        <th>Channel</th>
                        <th>When</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={entry <- @recent_urls}>
                        <td class="max-w-xs truncate">
                          <span class="font-mono text-sm" title={entry.url}>{entry.url}</span>
                        </td>
                        <td class="font-medium">{entry.nick}</td>
                        <td>{entry.channel}</td>
                        <td class="text-sm text-base-content/60">
                          {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M")}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>

          <%!-- Top Domains --%>
          <div>
            <div class="card bg-base-200 shadow-lg">
              <div class="card-body">
                <h2 class="card-title">Top Domains</h2>
                <div :if={@top_domains == []} class="text-base-content/50 italic">
                  No domains tracked yet.
                </div>
                <div class="space-y-2">
                  <div
                    :for={{domain, count} <- @top_domains}
                    class="flex justify-between items-center"
                  >
                    <span class="font-medium font-mono text-sm">{domain}</span>
                    <span class="badge badge-primary badge-lg">{count}</span>
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
