defmodule IrcBot.Repo.Migrations.CreateKarmaEntries do
  use Ecto.Migration

  def change do
    create table(:karma_entries) do
      add :username, :string, null: false
      add :score, :integer, null: false, default: 0
      add :channel, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:karma_entries, [:username, :channel])
    create index(:karma_entries, [:channel])
  end
end
