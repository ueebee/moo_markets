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
    new_state = update_job_execution(state, job_id, result)
    {:noreply, new_state}
  end

  # Private Functions

  defp initialize_jobs(state) do
    # 上場企業情報取得ジョブの初期化
    job = %Job{
      name: "上場企業情報取得",
      description: "J-Quants APIから上場企業情報を取得します",
      job_type: "listed_companies",
      schedule: "0 6 * * *",  # 毎日午前6時
      is_enabled: true
    }

    case Repo.insert(job) do
      {:ok, saved_job} ->
        # ジョブの実行履歴を取得
        executions = get_recent_executions([saved_job.id])
        |> Enum.map(fn execution -> {execution.id, execution} end)
        |> Map.new()

        # 次の実行時刻を計算
        next_run = calculate_next_run(saved_job.schedule)

        %{state |
          jobs: Map.put(state.jobs, saved_job.id, saved_job),
          executions: executions,
          next_runs: Map.put(state.next_runs, saved_job.id, next_run)
        }

      {:error, _} ->
        # ジョブが既に存在する場合は取得
        case Repo.get_by(Job, job_type: "listed_companies") do
          nil -> state
          existing_job ->
            # ジョブの実行履歴を取得
            executions = get_recent_executions([existing_job.id])
            |> Enum.map(fn execution -> {execution.id, execution} end)
            |> Map.new()

            # 次の実行時刻を計算
            next_run = calculate_next_run(existing_job.schedule)

            %{state |
              jobs: Map.put(state.jobs, existing_job.id, existing_job),
              executions: executions,
              next_runs: Map.put(state.next_runs, existing_job.id, next_run)
            }
        end
    end
  end

  defp get_recent_executions(job_ids) do
    Repo.all(
      from e in JobExecution,
        where: e.job_id in ^job_ids,
        order_by: [desc: e.started_at]
    )
  end

  defp update_job_execution(state, job_id, result) do
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
          Task.start(fn -> execute_job(state, job_id) end)
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

  defp execute_job(state, job_id) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found}

      job ->
        if job.is_enabled do
          # 実行中のジョブとしてマーク
          new_state = %{state | running_jobs: Map.put(state.running_jobs, job_id, true)}

          # ジョブ実行レコードを作成
          execution = %JobExecution{
            job_id: job_id,
            started_at: DateTime.utc_now() |> DateTime.truncate(:second),
            status: "running"
          }

          case Repo.insert(execution) do
            {:ok, saved_execution} ->
              # ジョブを非同期で実行
              Task.start(fn ->
                try do
                  result = JobRunner.run_job(job.job_type)
                  Process.send(self(), {:job_completed, job_id, result}, [])
                catch
                  kind, error ->
                    Process.send(self(), {:job_completed, job_id, {:error, {kind, error}}}, [])
                end
              end)

              {:ok, %{new_state | executions: Map.put(new_state.executions, saved_execution.id, saved_execution)}}

            {:error, _} ->
              {:error, :execution_creation_failed}
          end
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
