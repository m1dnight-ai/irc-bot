defmodule IrcBot.IRC.MessageBuffer do
  @moduledoc """
  In-memory ring buffer for recent IRC messages.

  Stores the last N messages so LiveViews can load history on mount.
  """

  use GenServer

  @max_messages 200

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Stores a message in the buffer."
  @spec push(IrcBot.IRC.Message.t()) :: :ok
  def push(message) do
    GenServer.cast(__MODULE__, {:push, message})
  end

  @doc "Returns recent messages, newest first."
  @spec recent(non_neg_integer()) :: [IrcBot.IRC.Message.t()]
  def recent(limit \\ 50) do
    GenServer.call(__MODULE__, {:recent, limit})
  end

  @doc "Returns recent messages for a specific channel, newest first."
  @spec recent_for_channel(String.t(), non_neg_integer()) :: [IrcBot.IRC.Message.t()]
  def recent_for_channel(channel, limit \\ 100) do
    GenServer.call(__MODULE__, {:recent_for_channel, channel, limit})
  end

  # --- Server ---

  @impl true
  def init(_opts), do: {:ok, :queue.new()}

  @impl true
  def handle_cast({:push, message}, queue) do
    {:noreply, enqueue_bounded(queue, message)}
  end

  @impl true
  def handle_call({:recent, limit}, _from, queue) do
    messages =
      queue
      |> :queue.to_list()
      |> Enum.reverse()
      |> Enum.take(limit)

    {:reply, messages, queue}
  end

  @impl true
  def handle_call({:recent_for_channel, channel, limit}, _from, queue) do
    messages =
      queue
      |> :queue.to_list()
      |> Enum.filter(&(&1.channel == channel))
      |> Enum.reverse()
      |> Enum.take(limit)

    {:reply, messages, queue}
  end

  defp enqueue_bounded(queue, message) do
    queue = :queue.in(message, queue)

    if :queue.len(queue) > @max_messages do
      {{:value, _}, queue} = :queue.out(queue)
      queue
    else
      queue
    end
  end
end
