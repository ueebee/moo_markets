defmodule MooMarkets.Scheduler.JobInterfaceTest do
  use ExUnit.Case
  doctest MooMarkets.Scheduler.JobInterface

  # テスト用のモックジョブモジュール
  defmodule MockJob do
    @behaviour MooMarkets.Scheduler.JobInterface

    @impl true
    def perform, do: :ok

    @impl true
    def description, do: "Test Job"

    @impl true
    def default_schedule, do: "0 0 * * *"
  end

  describe "behaviour" do
    test "MockJob implements all required callbacks" do
      assert :ok = MockJob.perform()
      assert "Test Job" = MockJob.description()
      assert "0 0 * * *" = MockJob.default_schedule()
    end
  end
end
