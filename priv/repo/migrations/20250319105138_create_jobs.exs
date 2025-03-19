defmodule MooMarkets.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :name, :string
      add :description, :text
      add :job_type, :string
      add :schedule, :string
      add :is_enabled, :boolean, default: false, null: false
      add :last_run_at, :utc_datetime
      add :next_run_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
