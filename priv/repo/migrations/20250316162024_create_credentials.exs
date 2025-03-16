defmodule MooMarkets.Repo.Migrations.CreateCredentials do
  use Ecto.Migration

  def change do
    create table(:credentials) do
      add :email, :string
      add :password, :string
      add :refresh_token, :text
      add :id_token, :text
      add :refresh_token_expires_at, :utc_datetime
      add :id_token_expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:credentials, [:email])
  end
end
