defmodule MooMarkets.JQuantsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MooMarkets.JQuants` context.
  """

  @doc """
  Generate a listed_company.
  """
  def listed_company_fixture(attrs \\ %{}) do
    {:ok, listed_company} =
      attrs
      |> Enum.into(%{
        code: "some code",
        company_name: "some company_name",
        company_name_english: "some company_name_english",
        last_updated_at: ~U[2025-03-17 03:30:00Z],
        margin_code: "some margin_code",
        margin_code_name: "some margin_code_name",
        market_code: "some market_code",
        market_code_name: "some market_code_name",
        scale_category: "some scale_category",
        sector17_code: "some sector17_code",
        sector17_code_name: "some sector17_code_name",
        sector33_code: "some sector33_code",
        sector33_code_name: "some sector33_code_name"
      })
      |> MooMarkets.JQuants.create_listed_company()

    listed_company
  end
end
