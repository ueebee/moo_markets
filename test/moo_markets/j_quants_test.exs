defmodule MooMarkets.JQuantsTest do
  use MooMarkets.DataCase

  alias MooMarkets.JQuants

  describe "listed_companies" do
    alias MooMarkets.JQuants.ListedCompany

    import MooMarkets.JQuantsFixtures

    @invalid_attrs %{code: nil, company_name: nil, company_name_english: nil, sector17_code: nil, sector17_code_name: nil, sector33_code: nil, sector33_code_name: nil, scale_category: nil, market_code: nil, market_code_name: nil, margin_code: nil, margin_code_name: nil, last_updated_at: nil}

    test "list_listed_companies/0 returns all listed_companies" do
      listed_company = listed_company_fixture()
      assert JQuants.list_listed_companies() == [listed_company]
    end

    test "get_listed_company!/1 returns the listed_company with given id" do
      listed_company = listed_company_fixture()
      assert JQuants.get_listed_company!(listed_company.id) == listed_company
    end

    test "create_listed_company/1 with valid data creates a listed_company" do
      valid_attrs = %{code: "some code", company_name: "some company_name", company_name_english: "some company_name_english", sector17_code: "some sector17_code", sector17_code_name: "some sector17_code_name", sector33_code: "some sector33_code", sector33_code_name: "some sector33_code_name", scale_category: "some scale_category", market_code: "some market_code", market_code_name: "some market_code_name", margin_code: "some margin_code", margin_code_name: "some margin_code_name", last_updated_at: ~U[2025-03-17 03:30:00Z]}

      assert {:ok, %ListedCompany{} = listed_company} = JQuants.create_listed_company(valid_attrs)
      assert listed_company.code == "some code"
      assert listed_company.company_name == "some company_name"
      assert listed_company.company_name_english == "some company_name_english"
      assert listed_company.sector17_code == "some sector17_code"
      assert listed_company.sector17_code_name == "some sector17_code_name"
      assert listed_company.sector33_code == "some sector33_code"
      assert listed_company.sector33_code_name == "some sector33_code_name"
      assert listed_company.scale_category == "some scale_category"
      assert listed_company.market_code == "some market_code"
      assert listed_company.market_code_name == "some market_code_name"
      assert listed_company.margin_code == "some margin_code"
      assert listed_company.margin_code_name == "some margin_code_name"
      assert listed_company.last_updated_at == ~U[2025-03-17 03:30:00Z]
    end

    test "create_listed_company/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = JQuants.create_listed_company(@invalid_attrs)
    end

    test "update_listed_company/2 with valid data updates the listed_company" do
      listed_company = listed_company_fixture()
      update_attrs = %{code: "some updated code", company_name: "some updated company_name", company_name_english: "some updated company_name_english", sector17_code: "some updated sector17_code", sector17_code_name: "some updated sector17_code_name", sector33_code: "some updated sector33_code", sector33_code_name: "some updated sector33_code_name", scale_category: "some updated scale_category", market_code: "some updated market_code", market_code_name: "some updated market_code_name", margin_code: "some updated margin_code", margin_code_name: "some updated margin_code_name", last_updated_at: ~U[2025-03-18 03:30:00Z]}

      assert {:ok, %ListedCompany{} = listed_company} = JQuants.update_listed_company(listed_company, update_attrs)
      assert listed_company.code == "some updated code"
      assert listed_company.company_name == "some updated company_name"
      assert listed_company.company_name_english == "some updated company_name_english"
      assert listed_company.sector17_code == "some updated sector17_code"
      assert listed_company.sector17_code_name == "some updated sector17_code_name"
      assert listed_company.sector33_code == "some updated sector33_code"
      assert listed_company.sector33_code_name == "some updated sector33_code_name"
      assert listed_company.scale_category == "some updated scale_category"
      assert listed_company.market_code == "some updated market_code"
      assert listed_company.market_code_name == "some updated market_code_name"
      assert listed_company.margin_code == "some updated margin_code"
      assert listed_company.margin_code_name == "some updated margin_code_name"
      assert listed_company.last_updated_at == ~U[2025-03-18 03:30:00Z]
    end

    test "update_listed_company/2 with invalid data returns error changeset" do
      listed_company = listed_company_fixture()
      assert {:error, %Ecto.Changeset{}} = JQuants.update_listed_company(listed_company, @invalid_attrs)
      assert listed_company == JQuants.get_listed_company!(listed_company.id)
    end

    test "delete_listed_company/1 deletes the listed_company" do
      listed_company = listed_company_fixture()
      assert {:ok, %ListedCompany{}} = JQuants.delete_listed_company(listed_company)
      assert_raise Ecto.NoResultsError, fn -> JQuants.get_listed_company!(listed_company.id) end
    end

    test "change_listed_company/1 returns a listed_company changeset" do
      listed_company = listed_company_fixture()
      assert %Ecto.Changeset{} = JQuants.change_listed_company(listed_company)
    end
  end
end
