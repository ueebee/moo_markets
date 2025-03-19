defmodule MooMarkets.Repo.Migrations.CreateJobExecutions do
  use Ecto.Migration

  def change do
    create table(:job_executions) do
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :status, :string
      add :error_message, :text
      add :job_id, references(:jobs, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:job_executions, [:job_id])
  end
end
