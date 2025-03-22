defmodule MooMarkets.Scheduler.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "jobs" do
    field :name, :string
    field :description, :string
    field :job_type, :string
    field :schedule, :string
    field :is_enabled, :boolean, default: false
    field :last_run_at, :utc_datetime
    field :next_run_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [:name, :description, :job_type, :schedule, :is_enabled, :last_run_at, :next_run_at])
    |> validate_required([:name, :job_type, :schedule, :is_enabled])
  end
end
