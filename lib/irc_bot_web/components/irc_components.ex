defmodule IrcBotWeb.IrcComponents do
  @moduledoc """
  Shared components for IRC message feeds and karma sidebars.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: IrcBotWeb.Endpoint,
    router: IrcBotWeb.Router,
    statics: IrcBotWeb.static_paths()

  @doc "Renders a single message row with timestamp, nick, and text."
  attr :msg, :map, required: true

  def message_item(assigns) do
    ~H"""
    <div id={"msg-#{System.unique_integer([:positive])}"} class="flex gap-2">
      <span class="text-base-content/40">
        {Calendar.strftime(@msg.timestamp, "%H:%M:%S")}
      </span>
      <span class="font-semibold text-primary">&lt;{@msg.nick}&gt;</span>
      <span>{@msg.text}</span>
    </div>
    """
  end

  @doc "Renders a message list with an empty-state fallback."
  attr :messages, :list, required: true
  attr :empty_text, :string, default: "No messages yet."

  def message_feed(assigns) do
    ~H"""
    <div class="overflow-y-auto max-h-96 space-y-1 font-mono text-sm" id="message-feed">
      <div :if={@messages == []} class="text-base-content/50 italic">
        {@empty_text}
      </div>
      <.message_item :for={msg <- @messages} msg={msg} />
    </div>
    """
  end

  @doc "Renders a karma leaderboard card with optional 'View Full Leaderboard' link."
  attr :karma_leaders, :list, required: true
  attr :title, :string, default: "Top Karma"
  attr :empty_text, :string, default: "No karma scores yet."
  attr :show_link, :boolean, default: false

  def karma_sidebar(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <h2 class="card-title">{@title}</h2>
        <div :if={@karma_leaders == []} class="text-base-content/50 italic">
          {@empty_text}
        </div>
        <div class="space-y-2">
          <div
            :for={{username, score} <- @karma_leaders}
            class="flex justify-between items-center"
          >
            <span class="font-medium">{username}</span>
            <span class="badge badge-primary badge-lg">{score}</span>
          </div>
        </div>
        <div :if={@show_link} class="card-actions justify-end mt-4">
          <.link navigate={~p"/karma"} class="btn btn-sm btn-outline">
            View Full Leaderboard
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
