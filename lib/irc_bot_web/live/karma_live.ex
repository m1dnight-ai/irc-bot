defmodule IrcBotWeb.KarmaLive do
  @moduledoc """
  Full karma leaderboard with real-time updates.
  """

  use IrcBotWeb, :live_view

  alias IrcBot.Plugins.Karma.Store

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(IrcBot.PubSub, "karma:updates")
    end

    {:ok,
     assign(socket,
       page_title: "Karma Leaderboard",
       leaders: Store.global_leaderboard(25)
     )}
  end

  @impl true
  def handle_info(%{event: :karma_changed}, socket) do
    {:noreply, assign(socket, :leaders, Store.global_leaderboard(25))}
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
          <h1 class="text-2xl font-bold">Karma Leaderboard</h1>
          <.link navigate={~p"/"} class="btn btn-sm btn-outline">
            Back to Dashboard
          </.link>
        </div>

        <div class="card bg-base-200 shadow-lg">
          <div class="card-body">
            <div :if={@leaders == []} class="text-base-content/50 italic text-center py-8">
              No karma scores yet. Use <code>username++</code> or <code>username--</code> in IRC!
            </div>
            <div class="overflow-x-auto">
              <table :if={@leaders != []} class="table">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>User</th>
                    <th>Score</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{{username, score}, rank} <- Enum.with_index(@leaders, 1)}>
                    <td>
                      <span class={rank_class(rank)}>{rank}</span>
                    </td>
                    <td class="font-medium">{username}</td>
                    <td>
                      <span class={[
                        "badge badge-lg",
                        score > 0 && "badge-success",
                        score < 0 && "badge-error",
                        score == 0 && "badge-neutral"
                      ]}>
                        {score}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp rank_class(1), do: "text-xl font-bold text-warning"
  defp rank_class(2), do: "text-lg font-semibold text-base-content/70"
  defp rank_class(3), do: "text-lg font-semibold text-accent"
  defp rank_class(_), do: "text-base-content/60"
end
