defmodule IrcBot.Plugins.Karma.Schema do
  @moduledoc """
  Ecto schema for karma entries.

  Each entry tracks a user's karma score within a specific channel.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "karma_entries" do
    field :username, :string
    field :score, :integer, default: 0
    field :channel, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating a karma entry."
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:username, :score, :channel])
    |> validate_required([:username, :channel])
    |> unique_constraint([:username, :channel])
  end
end
