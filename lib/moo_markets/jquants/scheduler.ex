defmodule MooMarkets.JQuants.Scheduler do
  @moduledoc """
  J-Quants APIから定期的にデータを取得するスケジューラー
  """
  use GenServer
  require Logger

  alias MooMarkets.JQuants.{Client, ListedCompany}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def fetch_data do
    GenServer.call(__MODULE__, :fetch_data)
  end

  @impl true
  def init(_) do
    schedule_work()
    {:ok, %{last_fetch: nil}}
  end

  @impl true
  def handle_call(:fetch_data, _from, state) do
    case fetch_and_save_data() do
      :ok ->
        {:reply, :ok, %{state | last_fetch: DateTime.utc_now()}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:work, state) do
    case fetch_and_save_data() do
      :ok ->
        Logger.info("Successfully fetched and saved listed companies data")
        schedule_work()
        {:noreply, %{state | last_fetch: DateTime.utc_now()}}
      {:error, reason} ->
        Logger.error("Failed to fetch and save listed companies data: #{inspect(reason)}")
        schedule_work()
        {:noreply, state}
    end
  end

  defp schedule_work do
    # 次の実行時刻を計算（毎日午前6時）
    now = DateTime.utc_now()
    next_run = NaiveDateTime.new!(
      now.year,
      now.month,
      now.day,
      6,
      0,
      0
    )
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.add(24 * 60 * 60, :second) # 次の日の6時

    # 遅延時間を計算（ミリ秒）
    delay = DateTime.diff(next_run, now) * 1000

    Process.send_after(self(), :work, delay)
  end

  defp fetch_and_save_data do
    with {:ok, companies} <- Client.fetch_listed_companies(),
         {:ok, _} <- save_companies(companies) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_companies(companies) do
    companies
    |> Enum.map(&transform_company_data/1)
    |> Enum.chunk_every(100)
    |> Enum.reduce_while(:ok, fn chunk, :ok ->
      case bulk_upsert_companies(chunk) do
        {:ok, _} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp bulk_upsert_companies(companies) do
    # バルクアップサートを実行
    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(
      :listed_companies,
      ListedCompany,
      companies,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :code
    )
    |> MooMarkets.Repo.transaction()
    |> case do
      {:ok, _} -> {:ok, companies}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp transform_company_data(company) do
    %{
      code: company["Code"],
      company_name: company["CompanyName"],
      company_name_english: company["CompanyNameEnglish"],
      sector17_code: company["Sector17Code"],
      sector17_code_name: company["Sector17CodeName"],
      sector33_code: company["Sector33Code"],
      sector33_code_name: company["Sector33CodeName"],
      market_code: company["MarketCode"],
      market_code_name: company["MarketCodeName"],
      scale_category: company["ScaleCategory"],
      margin_code: company["MarginCode"],
      last_updated_at: DateTime.utc_now()
    }
  end
end
