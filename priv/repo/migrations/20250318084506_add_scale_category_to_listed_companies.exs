defmodule MooMarkets.Repo.Migrations.AddScaleCategoryToListedCompanies do
  use Ecto.Migration

  def change do
    alter table(:listed_companies) do
      add :scale_category, :string
    end
  end
end
