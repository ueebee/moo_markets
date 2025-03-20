defmodule MooMarkets.Scheduler.Server do
  @moduledoc """
  Scheduler server that manages job execution and state.
  """
  use GenServer
  require Logger

  alias MooMarkets.Repo
  alias MooMarkets.Scheduler.{Job, JobExecution}
  alias MooMarkets.Scheduler.JobRunner
  import Ecto.Query

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def run_job(job_id) do
    GenServer.cast(__MODULE__, {:run_job, job_id})
  end

  def toggle_job(job_id) do
    GenServer.cast(__MODULE__, {:toggle_job, job_id})
  end

  @doc """
  Cleans up the running_jobs map by removing all entries.
  This is useful when the server state needs to be reset.
  """
  def cleanup_running_jobs do
    GenServer.cast(__MODULE__, :cleanup_running_jobs)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # 初期状態の設定
    state = %{
      jobs: %{},
      executions: %{},
      next_runs: %{},
      running_jobs: %{}
    }

    # ジョブの初期化
    state = initialize_jobs(state)

    # 定期的なジョブ状態の更新
    schedule_job_check()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:run_job, job_id}, state) do
    case Repo.get(Job, job_id) do
      nil ->
        Logger.warning("Job not found: #{job_id}")
        {:noreply, state}

      job ->
        if Map.has_key?(state.running_jobs, job_id) do
          Logger.warning("Job is already running: #{job_id}")
          {:noreply, state}
        else
          # ジョブを実行
          Task.start(fn -> execute_job(job) end)
          state = %{state | running_jobs: Map.put(state.running_jobs, job_id, DateTime.utc_now())}
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_cast({:toggle_job, job_id}, state) do
    case Repo.get(Job, job_id) do
      nil ->
        Logger.warning("Job not found: #{job_id}")
        {:noreply, state}

      job ->
        # ジョブの有効/無効を切り替え
        case Repo.update(Job.changeset(job, %{is_enabled: !job.is_enabled})) do
          {:ok, updated_job} ->
            Logger.info("Job #{job_id} toggled to #{!job.is_enabled}")
            state = %{state | jobs: Map.put(state.jobs, job_id, updated_job)}
            {:noreply, state}

          {:error, changeset} ->
            Logger.error("Failed to toggle job #{job_id}: #{inspect(changeset.errors)}")
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_cast(:cleanup_running_jobs, state) do
    Logger.info("Cleaning up running jobs")
    {:noreply, %{state | running_jobs: %{}}}
  end

  @impl true
  def handle_info(:check_jobs, state) do
    # 次の実行時刻をチェック
    now = DateTime.utc_now()
    state = check_and_run_due_jobs(state, now)

    # 実行中のジョブをチェック
    state = check_running_jobs(state)

    # 次のチェックをスケジュール
    schedule_job_check()

    {:noreply, state}
  end

  @impl true
  def handle_info({:job_completed, job_id, result}, state) do
    case result do
      :ok ->
        Logger.info("Job #{job_id} completed successfully")
        state = update_job_state(state, job_id, "completed")
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Job #{job_id} failed: #{inspect(reason)}")
        state = update_job_state(state, job_id, "failed", inspect(reason))
        {:noreply, state}
    end
  end

  # Private Functions

  defp initialize_jobs(state) do
    # データベースからジョブを取得
    jobs = Repo.all(Job)
    |> Enum.map(fn job -> {job.id, job} end)
    |> Map.new()

    # 各ジョブの実行履歴を取得
    executions = jobs
    |> Map.keys()
    |> get_recent_executions()
    |> Enum.map(fn execution -> {execution.job_id, execution} end)
    |> Map.new()

    # 次の実行時刻を計算
    next_runs = jobs
    |> Map.values()
    |> Enum.map(fn job -> {job.id, calculate_next_run(job.schedule)} end)
    |> Map.new()

    %{state |
      jobs: jobs,
      executions: executions,
      next_runs: next_runs
    }
  end

  defp get_recent_executions(job_ids) do
    Repo.all(
      from e in JobExecution,
        where: e.job_id in ^job_ids,
        order_by: [desc: e.started_at]
    )
  end

  defp update_job_state(state, job_id, status, error_message \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # ジョブの状態を更新
    current_job = Map.get(state.jobs, job_id)
    updated_job = current_job
    |> Job.changeset(%{
      last_run_at: now,
      next_run_at: calculate_next_run(current_job.schedule)
    })
    |> Repo.update!()

    # 実行履歴を更新
    execution = %JobExecution{
      job_id: job_id,
      started_at: now,
      completed_at: now,
      status: status,
      error_message: error_message
    }
    |> Repo.insert!()

    # 状態を更新（running_jobsから必ず削除）
    %{state |
      jobs: Map.put(state.jobs, job_id, updated_job),
      executions: Map.put(state.executions, job_id, execution),  # 最新の実行履歴を更新
      running_jobs: Map.delete(state.running_jobs, job_id)  # 必ず削除
    }
  end

  defp calculate_next_run(schedule) when is_binary(schedule) do
    # 一時的な実装: スケジュールの解析は後で実装
    # 現在は1時間後に設定
    DateTime.add(DateTime.utc_now(), 3600)
  end

  defp calculate_next_run(_), do: nil

  defp schedule_job_check do
    Process.send_after(self(), :check_jobs, :timer.minutes(1))
  end

  defp check_and_run_due_jobs(state, now) do
    state.jobs
    |> Enum.filter(fn {_id, job} ->
      job.is_enabled &&
      Map.has_key?(state.next_runs, job.id) &&
      DateTime.compare(Map.get(state.next_runs, job.id), now) == :lt
    end)
    |> Enum.reduce(state, fn {job_id, _job}, acc ->
      case Repo.get(Job, job_id) do
        nil -> acc
        job ->
          Task.start(fn -> execute_job(job) end)
          %{acc | running_jobs: Map.put(acc.running_jobs, job_id, DateTime.utc_now())}
      end
    end)
  end

  defp check_running_jobs(state) do
    now = DateTime.utc_now()
    state.running_jobs
    |> Enum.filter(fn {_job_id, start_time} ->
      DateTime.diff(now, start_time) > 3600  # 1時間以上実行中のジョブをチェック
    end)
    |> Enum.reduce(state, fn {job_id, _start_time}, acc ->
      Logger.warning("Job #{job_id} has been running for more than 1 hour")
      # ここでジョブの強制終了などの処理を追加できます
      acc
    end)
  end

  defp execute_job(job) do
    try do
      result = JobRunner.run_job(job.job_type)
      send(self(), {:job_completed, job.id, result})
    catch
      kind, reason ->
        Logger.error("Job #{job.id} crashed: #{inspect(reason)}")
        send(self(), {:job_completed, job.id, {:error, reason}})
    end
  end
end
