defmodule IrcBot.Plugins.UrlCounter.Schema do
  @moduledoc """
  Ecto schema for URL entries.

  Each entry tracks a URL that was shared in a specific channel by a user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "url_entries" do
    field :url, :string
    field :domain, :string
    field :nick, :string
    field :channel, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a URL entry."
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:url, :domain, :nick, :channel])
    |> validate_required([:url, :domain, :nick, :channel])
  end
end
