defmodule IrcBot.IRC.Client do
  @moduledoc """
  GenServer wrapping ExIRC for IRC connectivity.

  Manages connection lifecycle, channel joins, and message sending.
  Reconnects automatically on disconnection.
  """

  use GenServer

  require Logger

  @behaviour IrcBot.IRC.ClientBehaviour

  @reconnect_delay 5_000

  # --- Client API ---

  @doc "Starts the IRC client."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Sends a message to a channel."
  @spec send_message(String.t(), String.t()) :: :ok
  @impl IrcBot.IRC.ClientBehaviour
  def send_message(channel, text) do
    GenServer.cast(__MODULE__, {:send_message, channel, text})
  end

  @doc "Joins a channel."
  @spec join_channel(String.t()) :: :ok
  @impl IrcBot.IRC.ClientBehaviour
  def join_channel(channel) do
    GenServer.cast(__MODULE__, {:join_channel, channel})
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(opts) do
    config = irc_config(opts)

    {:ok, irc_client} = ExIRC.Client.start_link()
    ExIRC.Client.add_handler(irc_client, self())

    state = %{
      client: irc_client,
      host: config.host,
      port: config.port,
      nick: config.nick,
      channels: config.channels,
      connected: false
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:send_message, channel, text}, state) do
    if state.connected do
      ExIRC.Client.msg(state.client, :privmsg, channel, text)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:join_channel, channel}, state) do
    if state.connected do
      ExIRC.Client.join(state.client, channel)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:connect, state) do
    Logger.info("Connecting to IRC: #{state.host}:#{state.port}")
    ExIRC.Client.connect!(state.client, state.host, state.port)
    {:noreply, state}
  end

  # ExIRC handler: connected to server
  @impl GenServer
  def handle_info({:connected, _server, _port}, state) do
    Logger.info("Connected to IRC server, logging in as #{state.nick}")
    ExIRC.Client.logon(state.client, "", state.nick, state.nick, state.nick)
    {:noreply, state}
  end

  # ExIRC handler: logged in
  @impl GenServer
  def handle_info(:logged_in, state) do
    Logger.info("Logged in to IRC as #{state.nick}")

    Enum.each(state.channels, fn channel ->
      ExIRC.Client.join(state.client, channel)
    end)

    broadcast_event(:connected, %{nick: state.nick})
    {:noreply, %{state | connected: true}}
  end

  # ExIRC handler: joined channel
  @impl GenServer
  def handle_info({:joined, channel}, state) do
    Logger.info("Joined #{channel}")
    broadcast_event(:joined, %{channel: channel})
    {:noreply, state}
  end

  # ExIRC handler: received message
  @impl GenServer
  def handle_info({:received, text, %ExIRC.SenderInfo{nick: nick}, channel}, state) do
    message =
      IrcBot.IRC.Message.new(
        type: :privmsg,
        nick: nick,
        channel: channel,
        text: text
      )

    IrcBot.IRC.MessageBuffer.push(message)
    broadcast_event(:message, message)
    dispatch_and_reply(message, state)
  end

  # ExIRC handler: disconnected
  @impl GenServer
  def handle_info(:disconnected, state) do
    Logger.warning("Disconnected from IRC, reconnecting in #{@reconnect_delay}ms")
    broadcast_event(:disconnected, %{})
    Process.send_after(self(), :connect, @reconnect_delay)
    {:noreply, %{state | connected: false}}
  end

  # Catch-all for other ExIRC messages
  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private ---

  defp dispatch_and_reply(message, state) do
    replies = IrcBot.Plugin.Registry.dispatch(message)

    Enum.each(replies, fn {channel, text} ->
      ExIRC.Client.msg(state.client, :privmsg, channel, text)
    end)

    {:noreply, state}
  end

  defp broadcast_event(event, data) do
    Phoenix.PubSub.broadcast(IrcBot.PubSub, "irc:events", %{event: event, data: data})
  end

  defp irc_config(opts) do
    defaults = [host: "localhost", port: 6667, nick: "elixir_bot", channels: []]
    app_config = Application.get_env(:irc_bot, :irc, [])

    defaults
    |> Keyword.merge(app_config)
    |> Keyword.merge(opts)
    |> Map.new()
  end
end
