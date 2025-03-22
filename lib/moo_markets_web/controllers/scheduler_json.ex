defmodule MooMarketsWeb.SchedulerJSON do
  def status(%{state: state}) do
    %{
      jobs: render_jobs(state.jobs),
      running_jobs: state.running_jobs,
      executions: render_executions(state.executions)
    }
  end

  def jobs(%{jobs: jobs}) do
    %{jobs: render_jobs(jobs)}
  end

  def job(%{job: job}) do
    %{
      id: job.id,
      name: job.name,
      description: job.description,
      job_type: job.job_type,
      schedule: job.schedule,
      is_enabled: job.is_enabled,
      last_run_at: job.last_run_at,
      next_run_at: job.next_run_at
    }
  end

  def executions(%{executions: executions}) do
    %{
      executions: Enum.map(executions, fn execution ->
        %{
          id: execution.id,
          job_id: execution.job_id,
          started_at: execution.started_at,
          completed_at: execution.completed_at,
          status: execution.status,
          error_message: execution.error_message
        }
      end)
    }
  end

  defp render_jobs(jobs) do
    Enum.map(jobs, fn {id, job} ->
      %{
        id: id,
        name: job.name,
        description: job.description,
        job_type: job.job_type,
        schedule: job.schedule,
        is_enabled: job.is_enabled,
        last_run_at: job.last_run_at,
        next_run_at: job.next_run_at
      }
    end)
  end

  defp render_executions(executions) do
    Enum.map(executions, fn {id, execution} ->
      %{
        id: id,
        job_id: execution.job_id,
        started_at: execution.started_at,
        completed_at: execution.completed_at,
        status: execution.status,
        error_message: execution.error_message
      }
    end)
  end
end
