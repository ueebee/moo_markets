defmodule MooMarkets.Repo.Migrations.CreateListedCompanies do
  use Ecto.Migration

  def change do
    create table(:listed_companies) do
      add :code, :string, null: false
      add :company_name, :string, null: false
      add :company_name_english, :string
      add :sector17_code, :string, null: false
      add :sector17_code_name, :string, null: false
      add :sector33_code, :string, null: false
      add :sector33_code_name, :string, null: false
      add :scale_category, :string
      add :market_code, :string, null: false
      add :market_code_name, :string, null: false
      add :margin_code, :string
      add :margin_code_name, :string
      add :last_updated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:listed_companies, [:code])
    create index(:listed_companies, [:sector17_code])
    create index(:listed_companies, [:sector33_code])
    create index(:listed_companies, [:market_code])
  end
end
