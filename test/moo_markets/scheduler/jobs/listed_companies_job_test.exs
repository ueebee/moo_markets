defmodule MooMarkets.Scheduler.Jobs.ListedCompaniesJobTest do
  use MooMarkets.DataCase
  alias MooMarkets.Scheduler.Jobs.ListedCompaniesJob

  # モックモジュールを定義
  defmodule MockJQuants do
    def fetch_and_save_listed_companies do
      {:ok, []}
    end
  end

  defmodule MockJQuantsError do
    def fetch_and_save_listed_companies do
      {:error, :api_error}
    end
  end

  defmodule MockAuth do
    def get_active_credentials do
      {:ok, %{refresh_token: "test_token", id_token: "test_id_token"}}
    end
  end

  # テスト実行前にモックを設定
  setup do
    Application.put_env(:moo_markets, :jquants_module, MockJQuants)
    Application.put_env(:moo_markets, :auth_module, MockAuth)

    on_exit(fn ->
      Application.delete_env(:moo_markets, :jquants_module)
      Application.delete_env(:moo_markets, :auth_module)
    end)

    :ok
  end

  describe "perform/0" do
    test "successfully fetches and saves listed companies" do
      assert :ok = ListedCompaniesJob.perform()
    end

    test "returns error when API call fails" do
      # 環境変数を一時的に変更してMockJQuantsErrorを使用
      original_module = Application.get_env(:moo_markets, :jquants_module)
      Application.put_env(:moo_markets, :jquants_module, MockJQuantsError)

      assert {:error, :api_error} = ListedCompaniesJob.perform()

      # 環境変数を元に戻す
      Application.put_env(:moo_markets, :jquants_module, original_module)
    end
  end

  describe "description/0" do
    test "returns correct description" do
      assert "上場企業情報の取得" = ListedCompaniesJob.description()
    end
  end

  describe "default_schedule/0" do
    test "returns correct schedule" do
      assert "0 6 * * *" = ListedCompaniesJob.default_schedule()
    end
  end
end
