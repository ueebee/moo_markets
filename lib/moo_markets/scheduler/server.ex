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

  def toggle_job(job_id, enabled) do
    GenServer.call(__MODULE__, {:toggle_job, job_id, enabled})
  end

  @doc """
  Cleans up the running_jobs map by removing all entries.
  This is useful when the server state needs to be reset.
  """
  def cleanup_running_jobs do
    GenServer.cast(__MODULE__, :cleanup_running_jobs)
  end

  def get_job(job_id) do
    GenServer.call(__MODULE__, {:get_job, job_id})
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

    # 既存のジョブを読み込む
    jobs = MooMarkets.Repo.all(MooMarkets.Scheduler.Job)
    jobs_map = jobs |> Enum.map(fn job -> {job.id, job} end) |> Map.new()

    # 実行履歴を取得
    executions = get_recent_executions(Map.keys(jobs_map))
    |> Enum.map(fn execution -> {execution.id, execution} end)
    |> Map.new()

    # 次回実行時刻を計算
    next_runs = jobs
    |> Enum.map(fn job -> {job.id, calculate_next_run(job.schedule)} end)
    |> Map.new()

    state = %{state |
      jobs: jobs_map,
      executions: executions,
      next_runs: next_runs
    }

    # 定期的なジョブ状態の更新
    schedule_job_check()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:toggle_job, job_id, enabled}, _from, state) do
    case toggle_job(state, job_id, enabled) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_job, job_id}, _from, state) do
    case Map.get(state.jobs, job_id) do
      nil -> {:reply, {:error, :not_found}, state}
      job -> {:reply, {:ok, job}, state}
    end
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    # Implementation of cleanup
    # This function is not provided in the original file or the code block
    # It's assumed to exist as it's called in the handle_info function
    # Adding a placeholder implementation
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:run_job, job_id}, state) do
    case execute_job(state, job_id) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to execute job #{job_id}: #{inspect(reason)}")
        {:noreply, state}
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
    state = check_and_run_due_jobs(state)

    # 実行中のジョブをチェック
    state = check_running_jobs(state)

    # 次のチェックをスケジュール
    schedule_job_check()

    {:noreply, state}
  end

  @impl true
  def handle_info({:job_completed, job_id, result}, state) do
    new_state = update_job_execution(state, job_id, result)
    {:noreply, new_state}
  end

  # Private Functions

  defp get_recent_executions(job_ids) do
    Repo.all(
      from e in JobExecution,
        where: e.job_id in ^job_ids,
        order_by: [desc: e.started_at]
    )
  end

  defp update_job_execution(state, job_id, _result) do
    # 実行中のジョブから削除
    new_state = %{state | running_jobs: Map.delete(state.running_jobs, job_id)}

    # ジョブの最終実行時刻を更新
    case Map.get(new_state.jobs, job_id) do
      nil -> new_state
      job ->
        case Repo.update(Job.changeset(job, %{last_run_at: DateTime.utc_now() |> DateTime.truncate(:second)})) do
          {:ok, updated_job} ->
            new_jobs = Map.put(new_state.jobs, job_id, updated_job)
            %{new_state | jobs: new_jobs}
        end
    end
  end

  defp calculate_next_run(schedule) when is_binary(schedule) do
    try do
      # scheduleからcron式を解析
      case Crontab.CronExpression.Parser.parse(schedule) do
        {:ok, cron_expr} ->
          # 現在時刻から次の実行時刻を計算
          now = DateTime.utc_now() |> DateTime.to_naive()
          Crontab.Scheduler.get_next_run_date!(cron_expr, now)
          |> DateTime.from_naive!("Etc/UTC")

        {:error, reason} ->
          Logger.error("Failed to parse cron expression: #{schedule}, reason: #{inspect(reason)}")
          nil
      end
    rescue
      e ->
        Logger.error("Error calculating next run time: #{inspect(e)}")
        nil
    end
  end

  defp calculate_next_run(_), do: nil

  defp schedule_job_check do
    Process.send_after(self(), :check_jobs, :timer.minutes(1))
  end

  defp check_and_run_due_jobs(state) do
    now = DateTime.utc_now()

    # Filter and run due jobs
    due_jobs =
      state.jobs
      |> Enum.filter(fn {_id, job} ->
        job.is_enabled &&
        Map.has_key?(state.next_runs, job.id) &&
        DateTime.compare(Map.get(state.next_runs, job.id), now) == :lt
      end)

    # Run jobs and update last_run_at
    new_jobs =
      Enum.reduce(due_jobs, state.jobs, fn {job_id, _job}, acc ->
        case execute_job(state, job_id) do
          {:ok, _new_state} ->
            # Update last_run_at
            Map.update!(acc, job_id, fn j -> %{j | last_run_at: now} end)
          {:error, _reason} ->
            acc
        end
      end)

    # Recalculate next_runs for executed jobs
    new_next_runs =
      Enum.reduce(due_jobs, state.next_runs, fn {job_id, job}, acc ->
        next_run = calculate_next_run(job.schedule)
        Map.put(acc, job_id, next_run)
      end)

    %{state | jobs: new_jobs, next_runs: new_next_runs}
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

  defp execute_job(state, job_id) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found}

      job ->
        if job.is_enabled do
          now = DateTime.utc_now() |> DateTime.truncate(:second)
          # 実行中のジョブとしてマーク（開始時刻を保存）
          new_state = %{state | running_jobs: Map.put(state.running_jobs, job_id, now)}

          # GenServerプロセスのPIDを保持
          server = self()
          # job.job_typeの中身を確認
          IO.inspect(job.job_type, label: "Job type before Task.start")
          # ジョブを非同期で実行
          Task.start(fn ->
            try do
              result = JobRunner.run_job(job.job_type)
              Process.send(server, {:job_completed, job_id, result}, [])
            catch
              kind, error ->
                Process.send(server, {:job_completed, job_id, {:error, {kind, error}}}, [])
            end
          end)

          {:ok, new_state}
        else
          {:error, :job_disabled}
        end
    end
  end

  defp toggle_job(state, job_id, enabled) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found}

      job ->
        case Repo.update(Job.changeset(job, %{is_enabled: enabled})) do
          {:ok, updated_job} ->
            new_jobs = Map.put(state.jobs, job_id, updated_job)
            {:ok, %{state | jobs: new_jobs}}

          {:error, _} ->
            {:error, :update_failed}
        end
    end
  end
end
