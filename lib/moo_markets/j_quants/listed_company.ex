defmodule MooMarkets.JQuants.ListedCompany do
  use Ecto.Schema
  import Ecto.Changeset

  schema "listed_companies" do
    field :code, :string
    field :company_name, :string
    field :company_name_english, :string
    field :sector17_code, :string
    field :sector17_code_name, :string
    field :sector33_code, :string
    field :sector33_code_name, :string
    field :scale_category, :string
    field :market_code, :string
    field :market_code_name, :string
    field :margin_code, :string
    field :margin_code_name, :string
    field :last_updated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listed_company, attrs) do
    listed_company
    |> cast(attrs, [:code, :company_name, :company_name_english, :sector17_code, :sector17_code_name, :sector33_code, :sector33_code_name, :scale_category, :market_code, :market_code_name, :margin_code, :margin_code_name, :last_updated_at])
    |> validate_required([:code, :company_name, :sector17_code, :sector17_code_name, :sector33_code, :sector33_code_name, :market_code, :market_code_name])
    |> unique_constraint(:code)
  end
end
