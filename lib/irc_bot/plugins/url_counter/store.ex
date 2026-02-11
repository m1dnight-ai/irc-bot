defmodule IrcBot.Plugins.UrlCounter.Store do
  @moduledoc """
  Database operations for URL tracking.

  Stores URLs shared in IRC channels and provides queries for
  recent URLs and top domains.
  """

  import Ecto.Query

  alias IrcBot.Plugins.UrlCounter.Schema
  alias IrcBot.Repo

  @doc "Records a URL shared in a channel."
  @spec record_url(String.t(), String.t(), String.t(), String.t()) :: {:ok, Schema.t()}
  def record_url(url, domain, nick, channel) do
    %Schema{url: url, domain: domain, nick: nick, channel: channel}
    |> Repo.insert()
  end

  @doc "Returns the most recently shared URLs."
  @spec recent_urls(pos_integer()) :: [Schema.t()]
  def recent_urls(limit \\ 10) do
    Schema
    |> order_by([u], desc: u.inserted_at, desc: u.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Returns the most recently shared URLs for a specific channel."
  @spec recent_urls_for_channel(String.t(), pos_integer()) :: [Schema.t()]
  def recent_urls_for_channel(channel, limit \\ 10) do
    Schema
    |> where(channel: ^channel)
    |> order_by([u], desc: u.inserted_at, desc: u.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Returns the top domains by number of URLs shared."
  @spec top_domains(pos_integer()) :: [{String.t(), integer()}]
  def top_domains(limit \\ 10) do
    Schema
    |> group_by([u], u.domain)
    |> order_by([u], desc: count(u.id))
    |> limit(^limit)
    |> select([u], {u.domain, count(u.id)})
    |> Repo.all()
  end

  @doc "Returns the top domains for a specific channel."
  @spec top_domains_for_channel(String.t(), pos_integer()) :: [{String.t(), integer()}]
  def top_domains_for_channel(channel, limit \\ 10) do
    Schema
    |> where(channel: ^channel)
    |> group_by([u], u.domain)
    |> order_by([u], desc: count(u.id))
    |> limit(^limit)
    |> select([u], {u.domain, count(u.id)})
    |> Repo.all()
  end

  @doc "Returns the total number of tracked URLs."
  @spec total_count() :: integer()
  def total_count do
    Repo.aggregate(Schema, :count)
  end
end
