defmodule MooMarketsWeb.SchedulerLive.Index do
  use MooMarketsWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # 定期的な更新を設定（10秒ごと）
      :timer.send_interval(10_000, self(), :update)
    end

    {:ok, assign(socket, jobs: fetch_jobs(), page_title: "ジョブ一覧")}
  end

  @impl true
  def handle_info(:update, socket) do
    {:noreply, assign(socket, jobs: fetch_jobs())}
  end

  @impl true
  def handle_event("toggle_job", %{"id" => id, "enabled" => enabled}, socket) do
    case MooMarkets.Scheduler.Server.toggle_job(String.to_integer(id), enabled) do
      :ok ->
        {:noreply, assign(socket, jobs: fetch_jobs())}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "ジョブの状態変更に失敗しました: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("run_job", %{"id" => id}, socket) do
    case MooMarkets.Scheduler.Server.run_job(String.to_integer(id)) do
      :ok ->
        {:noreply,
          socket
          |> put_flash(:info, "ジョブを実行開始しました")
          |> assign(jobs: fetch_jobs())}
    end
  end

  defp fetch_jobs do
    state = MooMarkets.Scheduler.Server.get_state()
    state.jobs
  end
end
