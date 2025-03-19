defmodule MooMarkets.Scheduler.JobRunner do
  @moduledoc """
  Handles the execution of scheduled jobs.
  """

  alias MooMarkets.Repo
  alias MooMarkets.Scheduler.{Job, JobExecution}

  @doc """
  Runs a job of the specified type.
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def run_job(job_type) do
    job_module = job_module_from_type(job_type)
    job = get_job(job_type)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    execution = %JobExecution{
      job_id: job.id,
      started_at: now,
      status: "running"
    }
    |> Repo.insert!()

    case job_module.perform() do
      :ok ->
        execution
        |> JobExecution.changeset(%{
          status: "completed",
          completed_at: now
        })
        |> Repo.update!()

        job
        |> Job.changeset(%{
          last_run_at: now,
          next_run_at: calculate_next_run(job.schedule)
        })
        |> Repo.update!()

        :ok

      {:error, reason} ->
        execution
        |> JobExecution.changeset(%{
          status: "failed",
          completed_at: now,
          error_message: inspect(reason)
        })
        |> Repo.update!()

        {:error, reason}
    end
  end

  defp job_module_from_type("listed_companies"), do: MooMarkets.Scheduler.Jobs.ListedCompaniesJob
  defp job_module_from_type(_), do: {:error, :unknown_job_type}

  defp get_job(job_type) do
    case Repo.get_by(Job, job_type: job_type) do
      nil -> {:error, :job_not_found}
      job -> job
    end
  end

  defp calculate_next_run(_schedule) do
    # TODO: Implement cron schedule parsing and next run calculation
    # For now, just return nil
    nil
  end
end
