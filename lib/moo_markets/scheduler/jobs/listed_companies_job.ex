defmodule MooMarkets.Scheduler.Jobs.ListedCompaniesJob do
  @moduledoc """
  Job that fetches listed companies information from J-Quants API.
  """
  @behaviour MooMarkets.Scheduler.JobInterface

  @impl true
  def perform do
    case jquants_module().fetch_and_save_listed_companies() do
      {:ok, _companies} -> :ok
      {:ok, []} -> :ok  # 空のリストも成功として扱う
      {:error, %{message: message, status: status}} -> {:error, "API Error: #{message} (Status: #{status})"}
      {:error, reason} -> {:error, reason}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
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

  defp jquants_module do
    Application.get_env(:moo_markets, :jquants_module, MooMarkets.JQuants)
  end
end
