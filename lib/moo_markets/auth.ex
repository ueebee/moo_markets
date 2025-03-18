defmodule MooMarkets.Auth do
  @moduledoc """
  The Auth context.
  Handles J-Quants API authentication and credential management.
  """

  import Ecto.Query, warn: false
  alias MooMarkets.Repo
  alias MooMarkets.Auth.Credentials

  @doc """
  Returns the list of credentials.
  """
  def list_credentials do
    Repo.all(Credentials)
  end

  @doc """
  Gets a single credentials.
  Returns nil if the Credentials does not exist.
  """
  def get_credentials(id), do: Repo.get(Credentials, id)

  @doc """
  Gets a single credentials by email.
  Returns nil if the Credentials does not exist.
  """
  def get_credentials_by_email(email) when is_binary(email) do
    Repo.get_by(Credentials, email: email)
  end

  @doc """
  Creates credentials.
  """
  def create_credentials(attrs \\ %{}) do
    %Credentials{}
    |> Credentials.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates credentials.
  """
  def update_credentials(%Credentials{} = credentials, attrs) do
    credentials
    |> Credentials.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates credentials tokens.
  """
  def update_credentials_tokens(%Credentials{} = credentials, attrs) do
    credentials
    |> Credentials.token_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes credentials.
  """
  def delete_credentials(%Credentials{} = credentials) do
    Repo.delete(credentials)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking credentials changes.
  """
  def change_credentials(%Credentials{} = credentials, attrs \\ %{}) do
    Credentials.changeset(credentials, attrs)
  end

  @doc """
  有効な認証情報を取得します
  """
  def get_active_credentials do
    Credentials
    |> where([c], not is_nil(c.refresh_token) and not is_nil(c.id_token))
    |> order_by([c], desc: c.updated_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :no_credentials}
      credentials -> {:ok, credentials}
    end
  end

  @doc """
  Gets credentials that need token refresh.
  These are credentials where the ID token is expired but the refresh token is still valid.
  """
  def get_credentials_needing_refresh do
    query =
      from c in Credentials,
        where: not is_nil(c.refresh_token) and not is_nil(c.id_token),
        order_by: [desc: c.updated_at]

    Repo.all(query)
    |> Enum.filter(fn credentials ->
      not Credentials.refresh_token_expired?(credentials) and Credentials.id_token_expired?(credentials)
    end)
  end
end
