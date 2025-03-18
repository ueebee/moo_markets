defmodule MooMarkets.Auth.JQuantsApi do
  @moduledoc """
  J-Quants API クライアント
  https://jpx.gitbook.io/j-quants-api/
  """

  use Tesla

  alias MooMarkets.Auth
  alias MooMarkets.Auth.Credentials

  @base_url "https://api.jquants.com/v1"

  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]

  @doc """
  リフレッシュトークンを取得します。
  メールアドレスとパスワードを使用して認証を行います。

  ## パラメータ
    - email: メールアドレス
    - password: パスワード

  ## 戻り値
    - {:ok, refresh_token} - 成功時
    - {:error, reason} - エラー時
  """
  def get_refresh_token(email, password) do
    with {:ok, response} <- post("/token/auth_user", %{
           "mailaddress" => email,
           "password" => password
         }),
         %{status: 200, body: %{"refreshToken" => refresh_token}} <- response do
      # リフレッシュトークンの有効期限は7日間
      refresh_token_expires_at = DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)
      {:ok, %{refresh_token: refresh_token, refresh_token_expires_at: refresh_token_expires_at}}
    else
      %{status: status, body: body} -> {:error, %{status: status, body: body}}
      error -> {:error, error}
    end
  end

  @doc """
  IDトークンを取得します。
  リフレッシュトークンを使用して認証を行います。

  ## パラメータ
    - refresh_token: リフレッシュトークン

  ## 戻り値
    - {:ok, id_token} - 成功時
    - {:error, reason} - エラー時
  """
  def get_id_token(refresh_token) do
    # 仕様に基づき、クエリパラメータとしてリフレッシュトークンを送信
    with {:ok, response} <- post("/token/auth_refresh?refreshtoken=#{refresh_token}", ""),
         %{status: 200, body: %{"idToken" => id_token}} <- response do
      # IDトークンの有効期限は24時間
      id_token_expires_at = DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)
      {:ok, %{id_token: id_token, id_token_expires_at: id_token_expires_at}}
    else
      %{status: status, body: body} -> {:error, %{status: status, body: body}}
      error -> {:error, error}
    end
  end

  @doc """
  認証情報を使用してトークンを更新します。
  リフレッシュトークンが有効な場合はIDトークンのみを更新し、
  リフレッシュトークンが無効な場合は両方のトークンを更新します。

  ## パラメータ
    - credentials: 認証情報

  ## 戻り値
    - {:ok, updated_credentials} - 成功時
    - {:error, reason} - エラー時
  """
  def refresh_tokens(%Credentials{} = credentials) do
    cond do
      # リフレッシュトークンが無効な場合は、両方のトークンを更新
      Credentials.refresh_token_expired?(credentials) ->
        with {:ok, refresh_result} <- get_refresh_token(credentials.email, credentials.password),
             {:ok, id_result} <- get_id_token(refresh_result.refresh_token) do
          Auth.update_credentials_tokens(credentials, Map.merge(refresh_result, id_result))
        end

      # IDトークンのみ期限切れの場合は、IDトークンのみを更新
      Credentials.id_token_expired?(credentials) ->
        with {:ok, id_result} <- get_id_token(credentials.refresh_token) do
          Auth.update_credentials_tokens(credentials, id_result)
        end

      # 両方のトークンが有効な場合は、そのまま返す
      true ->
        {:ok, credentials}
    end
  end

  @doc """
  アクティブな認証情報を取得し、必要に応じてトークンを更新します。

  ## 戻り値
    - {:ok, credentials} - 成功時（有効なトークンを持つ認証情報）
    - {:error, :no_credentials} - 認証情報が存在しない場合
    - {:error, reason} - その他のエラー
  """
  def ensure_active_credentials do
    case Auth.get_active_credentials() do
      {:error, :no_credentials} ->
        case Auth.get_credentials_needing_refresh() do
          [credentials | _] -> refresh_tokens(credentials)
          [] -> {:error, :no_credentials}
        end

      {:ok, credentials} ->
        {:ok, credentials}
    end
  end
end
