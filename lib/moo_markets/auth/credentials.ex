defmodule MooMarkets.Auth.Credentials do
  use Ecto.Schema
  import Ecto.Changeset

  schema "credentials" do
    field :password, :string
    field :email, :string
    field :refresh_token, :string
    field :id_token, :string
    field :refresh_token_expires_at, :utc_datetime
    field :id_token_expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating credentials.
  Only email and password are required.
  """
  def changeset(credentials, attrs) do
    credentials
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_length(:email, min: 5, max: 160)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "メールアドレスの形式が正しくありません")
    |> validate_length(:password, min: 6, max: 80)
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for updating tokens.
  All token-related fields are required when updating tokens.
  """
  def token_changeset(credentials, attrs) do
    credentials
    |> cast(attrs, [:refresh_token, :id_token, :refresh_token_expires_at, :id_token_expires_at])
    |> validate_required([:refresh_token, :id_token, :refresh_token_expires_at, :id_token_expires_at])
  end

  @doc """
  Checks if the refresh token is expired.
  """
  def refresh_token_expired?(%__MODULE__{} = credentials) do
    case credentials.refresh_token_expires_at do
      nil -> true
      expires_at -> DateTime.compare(expires_at, DateTime.utc_now()) == :lt
    end
  end

  @doc """
  Checks if the ID token is expired.
  """
  def id_token_expired?(%__MODULE__{} = credentials) do
    case credentials.id_token_expires_at do
      nil -> true
      expires_at -> DateTime.compare(expires_at, DateTime.utc_now()) == :lt
    end
  end
end
