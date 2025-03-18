defmodule MooMarkets.JQuants do
  @moduledoc """
  The JQuants context.
  """

  import Ecto.Query, warn: false
  alias MooMarkets.Repo

  alias MooMarkets.JQuants.ListedCompany

  @doc """
  Returns the list of listed_companies with pagination.

  ## Examples

      iex> list_listed_companies(%{page: 1, per_page: 100})
      %{entries: [%ListedCompany{}, ...], total_entries: 1000, total_pages: 10}

  """
  def list_listed_companies(params \\ %{}) do
    page = Map.get(params, :page, 1)
    per_page = Map.get(params, :per_page, 100)
    offset = (page - 1) * per_page

    query = from l in ListedCompany,
      order_by: [asc: l.code],
      limit: ^per_page,
      offset: ^offset

    total_query = from l in ListedCompany, select: count(l.id)
    total_entries = Repo.one(total_query)
    total_pages = ceil(total_entries / per_page)

    %{
      entries: Repo.all(query),
      total_entries: total_entries,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page
    }
  end

  @doc """
  Gets a single listed_company by code.

  Raises `Ecto.NoResultsError` if the Listed company does not exist.

  ## Examples

      iex> get_listed_company_by_code!("1234")
      %ListedCompany{}

      iex> get_listed_company_by_code!("9999")
      ** (Ecto.NoResultsError)

  """
  def get_listed_company_by_code!(code) do
    Repo.get_by!(ListedCompany, code: code)
  end

  @doc """
  Creates a listed_company.

  ## Examples

      iex> create_listed_company(%{field: value})
      {:ok, %ListedCompany{}}

      iex> create_listed_company(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_listed_company(attrs \\ %{}) do
    %ListedCompany{}
    |> ListedCompany.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a listed_company.

  ## Examples

      iex> update_listed_company(listed_company, %{field: new_value})
      {:ok, %ListedCompany{}}

      iex> update_listed_company(listed_company, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_listed_company(%ListedCompany{} = listed_company, attrs) do
    listed_company
    |> ListedCompany.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Bulk updates or creates listed companies.

  ## Examples

      iex> bulk_upsert_companies([%{code: "1234", company_name: "Example"}, ...])
      {:ok, [%ListedCompany{}, ...]}

      iex> bulk_upsert_companies([%{code: "1234", company_name: nil}, ...])
      {:error, %Ecto.Changeset{}}

  """
  def bulk_upsert_companies(companies) do
    Repo.transaction(fn ->
      Enum.map(companies, fn attrs ->
        case get_listed_company_by_code(attrs.code) do
          nil -> create_listed_company(attrs)
          company -> update_listed_company(company, attrs)
        end
      end)
    end)
  end

  @doc """
  Gets a single listed_company by code.

  Returns nil if the Listed company does not exist.

  ## Examples

      iex> get_listed_company_by_code("1234")
      %ListedCompany{}

      iex> get_listed_company_by_code("9999")
      nil

  """
  def get_listed_company_by_code(code) do
    Repo.get_by(ListedCompany, code: code)
  end

  @doc """
  Deletes a listed_company.

  ## Examples

      iex> delete_listed_company(listed_company)
      {:ok, %ListedCompany{}}

      iex> delete_listed_company(listed_company)
      {:error, %Ecto.Changeset{}}

  """
  def delete_listed_company(%ListedCompany{} = listed_company) do
    Repo.delete(listed_company)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking listed_company changes.

  ## Examples

      iex> change_listed_company(listed_company)
      %Ecto.Changeset{data: %ListedCompany{}}

  """
  def change_listed_company(%ListedCompany{} = listed_company, attrs \\ %{}) do
    ListedCompany.changeset(listed_company, attrs)
  end
end
