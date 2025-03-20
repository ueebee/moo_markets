defmodule MooMarkets.Scheduler.JobRunner do
  @moduledoc """
  Handles the execution of scheduled jobs.
  """

  alias MooMarkets.Repo
  alias MooMarkets.Scheduler.{Job, JobExecution}
  alias MooMarkets.Scheduler.Server
  import Ecto.Query

  @doc """
  Runs a job of the specified type.
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def run_job(job_type) do
    job_module = job_module_from_type(job_type)
    case get_job(job_type) do
      {:error, reason} -> {:error, reason}
      job ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # 実行中のジョブをチェック
        if has_running_execution?(job.id) do
          {:error, :job_already_running}
        else
          execution = create_execution(job.id, now)
          result = execute_job_with_cleanup(job, job_module, execution, now)
          # Serverに結果を通知
          send(Server, {:job_completed, job.id, result})
          # 実行結果を返す前に少し待つ
          Process.sleep(100)
          result
        end
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

  defp has_running_execution?(job_id) do
    Repo.exists?(
      from e in JobExecution,
        where: e.job_id == ^job_id and e.status == "running"
    )
  end

  defp create_execution(job_id, now) do
    %JobExecution{
      job_id: job_id,
      started_at: now,
      status: "running"
    }
    |> Repo.insert!()
  end

  defp execute_job_with_cleanup(job, job_module, execution, now) do
    try do
      result = job_module.perform()
      update_execution_status(execution, result, now)
      update_job_status(job, now)
      result
    catch
      kind, reason ->
        error = %{kind: kind, reason: reason}
        update_execution_status(execution, {:error, error}, now)
        {:error, error}
    end
  end

  defp update_execution_status(execution, result, now) do
    case result do
      :ok ->
        JobExecution.changeset(execution, %{
          status: "completed",
          completed_at: now
        })
        |> Repo.update!()
      {:error, reason} ->
        JobExecution.changeset(execution, %{
          status: "failed",
          completed_at: now,
          error_message: inspect(reason)
        })
        |> Repo.update!()
    end
  end

  defp update_job_status(job, now) do
    Job.changeset(job, %{
      last_run_at: now,
      next_run_at: calculate_next_run(job.schedule)
    })
    |> Repo.update!()
  end

  defp calculate_next_run(_schedule) do
    # TODO: Implement cron schedule parsing and next run calculation
    # For now, just return nil
    nil
  end
end
