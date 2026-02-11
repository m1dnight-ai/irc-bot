defmodule IrcBot.Plugin.Registry do
  @moduledoc """
  GenServer that manages loaded plugins and dispatches IRC messages.

  Loads plugins from application config on startup, routes incoming messages
  to matching plugins, and collects replies for the IRC client to send.
  """

  use GenServer

  require Logger

  alias IrcBot.IRC.Message

  # --- Client API ---

  @doc "Starts the plugin registry."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Dispatches a message to all matching plugins. Returns list of `{channel, text}` replies."
  @spec dispatch(Message.t(), GenServer.server()) :: [{String.t(), String.t()}]
  def dispatch(%Message{} = message, server \\ __MODULE__) do
    GenServer.call(server, {:dispatch, message})
  end

  @doc "Returns the list of currently loaded plugins with their names."
  @spec list_plugins(GenServer.server()) :: [
          %{module: module(), name: String.t(), description: String.t()}
        ]
  def list_plugins(server \\ __MODULE__) do
    GenServer.call(server, :list_plugins)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    plugins = Keyword.get(opts, :plugins, Application.get_env(:irc_bot, :plugins, []))
    loaded = load_plugins(plugins)
    {:ok, %{plugins: loaded}}
  end

  @impl true
  def handle_call({:dispatch, message}, _from, state) do
    {replies, new_plugins} = dispatch_to_plugins(message, state.plugins)
    {:reply, replies, %{state | plugins: new_plugins}}
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    info =
      Enum.map(state.plugins, fn {module, _state} ->
        %{module: module, name: module.name(), description: module.description()}
      end)

    {:reply, info, state}
  end

  # --- Private ---

  defp load_plugins(plugin_modules) do
    Enum.flat_map(plugin_modules, fn module ->
      case module.init([]) do
        {:ok, plugin_state} ->
          Logger.info("Loaded plugin: #{module.name()}")
          [{module, plugin_state}]

        {:error, reason} ->
          Logger.warning("Failed to load plugin #{module.name()}: #{inspect(reason)}")
          []
      end
    end)
  end

  defp dispatch_to_plugins(message, plugins) do
    Enum.map_reduce(plugins, [], fn {module, plugin_state}, acc_replies ->
      if module.handles?(message) do
        case module.handle_message(message, plugin_state) do
          {:reply, replies, new_state} ->
            {{module, new_state}, acc_replies ++ replies}

          {:noreply, new_state} ->
            {{module, new_state}, acc_replies}
        end
      else
        {{module, plugin_state}, acc_replies}
      end
    end)
    |> then(fn {updated_plugins, replies} -> {replies, updated_plugins} end)
  end
end
