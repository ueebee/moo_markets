defmodule MooMarkets.Repo.Migrations.AddUniqueConstraintToJobs do
  use Ecto.Migration

  def change do
    create unique_index(:jobs, [:job_type])
  end
end
