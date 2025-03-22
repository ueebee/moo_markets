defmodule MooMarkets.Scheduler.JobExecution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "job_executions" do
    field :status, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :job_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job_execution, attrs) do
    job_execution
    |> cast(attrs, [:started_at, :completed_at, :status, :error_message, :job_id])
    |> validate_required([:started_at, :status, :job_id])
  end
end
