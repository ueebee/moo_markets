defmodule MooMarketsWeb.SchedulerController do
  use MooMarketsWeb, :controller

  alias MooMarkets.Scheduler.Server

  def get_status(conn, _params) do
    state = Server.get_state()
    render(conn, :status, state: state)
  end

  def toggle_enabled(conn, %{"enabled" => enabled}) do
    case Server.toggle_job(1, enabled) do
      :ok ->
        state = Server.get_state()
        render(conn, :status, state: state)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def get_jobs(conn, _params) do
    state = Server.get_state()
    render(conn, :jobs, jobs: state.jobs)
  end

  def get_job(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {job_id, ""} ->
        case Server.get_job(job_id) do
          {:ok, job} ->
            render(conn, :job, job: job)
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Job not found"})
        end
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid job ID"})
    end
  end

  def run_job(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {job_id, ""} ->
        state = Server.get_state()
        case Map.get(state.jobs, job_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Job not found"})

          job ->
            if job.is_enabled do
              if Map.has_key?(state.running_jobs, job_id) do
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Job is already running"})
              else
                Server.run_job(job_id)
                conn
                |> put_status(:accepted)
                |> json(%{message: "Job execution started"})
              end
            else
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Job is disabled"})
            end
        end
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid job ID"})
    end
  end

  def cleanup(conn, _params) do
    Server.cleanup_running_jobs()
    conn
    |> put_status(:ok)
    |> json(%{message: "Running jobs cleaned up"})
  end
end
