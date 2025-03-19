defmodule MooMarkets.Scheduler.Jobs.ListedCompaniesJob do
  @moduledoc """
  Job that fetches listed companies information from J-Quants API.
  """
  @behaviour MooMarkets.Scheduler.JobInterface

  alias MooMarkets.JQuants

  @impl true
  def perform do
    case JQuants.fetch_and_save_listed_companies() do
      {:ok, _companies} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def description do
    "上場企業情報の取得"
  end

  @impl true
  def default_schedule do
    "0 6 * * *"  # 毎日午前6時に実行
  end
end
