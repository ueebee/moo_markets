defmodule MooMarkets.JQuants.Client do
  @moduledoc """
  J-Quants API クライアント
  """

  use Tesla

  require Logger

  plug Tesla.Middleware.BaseUrl, "https://api.jquants.com/v1"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

  @doc """
  上場企業一覧を取得します
  """
  def fetch_listed_companies do
    with {:ok, credentials} <- MooMarkets.Auth.get_active_credentials() do
      fetch_listed_companies_with_pagination(credentials.id_token)
    else
      {:error, reason} ->
        Logger.error("Failed to fetch listed companies: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_listed_companies_with_pagination(id_token, pagination_key \\ nil) do
    url = if pagination_key, do: "/listed/info?pagination_key=#{pagination_key}", else: "/listed/info"

    case get(url, headers: [{"Authorization", "Bearer #{id_token}"}]) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        case body do
          %{"info" => companies, "pagination_key" => next_key} ->
            # 次のページがある場合、再帰的に取得
            case fetch_listed_companies_with_pagination(id_token, next_key) do
              {:ok, next_companies} -> {:ok, companies ++ next_companies}
              {:error, reason} -> {:error, reason}
            end
          %{"info" => companies} ->
            # 最後のページ
            {:ok, companies}
          _ ->
            {:error, "Unexpected response format"}
        end
      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Failed to fetch listed companies. Status: #{status}, Body: #{inspect(body)}")
        {:error, "API request failed with status #{status}"}
      {:error, reason} ->
        Logger.error("Failed to fetch listed companies: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
