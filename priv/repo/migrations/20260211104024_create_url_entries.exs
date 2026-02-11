defmodule IrcBot.Repo.Migrations.CreateUrlEntries do
  use Ecto.Migration

  def change do
    create table(:url_entries) do
      add :url, :string, null: false
      add :domain, :string, null: false
      add :nick, :string, null: false
      add :channel, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:url_entries, [:channel])
    create index(:url_entries, [:domain])
  end
end
