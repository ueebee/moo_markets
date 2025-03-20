defmodule MooMarketsWeb.SchedulerController do
  use MooMarketsWeb, :controller

  alias MooMarkets.Scheduler.Server

  def status(conn, _params) do
    state = Server.get_state()
    render(conn, :status, state: state)
  end

  def list_jobs(conn, _params) do
    state = Server.get_state()
    render(conn, :jobs, jobs: state.jobs)
  end

  def get_job(conn, %{"id" => id}) do
    state = Server.get_state()
    case Map.get(state.jobs, String.to_integer(id)) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Job not found"})

      job ->
        render(conn, :job, job: job)
    end
  end

  def toggle_job_enabled(conn, %{"id" => id, "enabled" => enabled}) when is_boolean(enabled) do
    case Server.toggle_job(String.to_integer(id), enabled) do
      :ok ->
        state = Server.get_state()
        render(conn, :status, state: state)

      {:error, :job_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Job not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def toggle_job_enabled(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "enabled parameter must be a boolean"})
  end
end
