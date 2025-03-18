defmodule MooMarkets.Auth.JQuantsApiTest do
  use MooMarkets.DataCase, async: false

  alias MooMarkets.Auth.JQuantsApi
  alias MooMarkets.Auth.Credentials
  import Tesla.Mock

  @mock_refresh_token "mockRefreshToken"
  @mock_id_token "mockIdToken"
  @valid_email "test@example.com"
  @valid_password "password123"

  # デバッグ用のシンプルなロガー
  # defp debug_log(message) do
  #   File.write!("test_debug.log", "#{message}\n", [:append])
  # end

  setup do
    # 重要: テスト環境でTesla.Mockをアダプターとして設定
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # デバッグログファイルをリセット
    # File.write!("test_debug.log", "")

    mock(fn
      %{method: :post, url: url, body: body} ->
        # debug_log("URL: #{url}")
        # debug_log("Body type: #{typeof(body)}")
        # debug_log("Body: #{inspect(body)}")

        cond do
          String.ends_with?(url, "/token/auth_user") ->
            # URLのマッチングに成功したらログに記録
            # debug_log("Matched /token/auth_user endpoint")

            # ボディを解析
            body_data = parse_body(body)
            # debug_log("Parsed body: #{inspect(body_data)}")

            # ユーザー認証情報の確認
            case body_data do
              %{"mailaddress" => @valid_email, "password" => @valid_password} ->
                # debug_log("Credentials matched - returning success")
                %Tesla.Env{
                  status: 200,
                  body: %{
                    "refreshToken" => @mock_refresh_token
                  }
                }
              _ ->
                # debug_log("Credentials did not match - returning error")
                # debug_log("Expected: %{\"mailaddress\" => \"test@example.com\", \"password\" => \"password123\"}")
                # debug_log("Got: #{inspect(body_data)}")
                %Tesla.Env{
                  status: 400,
                  body: %{
                    "message" => "'mailaddress' or 'password' is incorrect."
                  }
                }
            end

          # リフレッシュトークンを使ったIDトークン取得
          String.ends_with?(url, "/token/auth_refresh?refreshtoken=" <> @mock_refresh_token) ->
            # debug_log("Matched ID token with valid refresh token")
            %Tesla.Env{
              status: 200,
              body: %{"idToken" => @mock_id_token, "expires_in" => 3600}
            }

          # 無効なリフレッシュトークンでのIDトークン取得
          String.contains?(url, "/token/auth_refresh?refreshtoken=") &&
          !String.ends_with?(url, "/token/auth_refresh?refreshtoken=" <> @mock_refresh_token) ->
            # debug_log("Matched ID token with invalid refresh token")
            %Tesla.Env{
              status: 400,
              body: %{"message" => "The incoming token is invalid or expired."}
            }

          true ->
            # debug_log("No URL match found")
            %Tesla.Env{status: 404, body: "Not found"}
        end
    end)

    on_exit(fn ->
      # テスト終了後に設定を元に戻す
      Application.delete_env(:tesla, :adapter)
    end)

    :ok
  end

  describe "get_refresh_token/2" do
    test "returns refresh token with valid credentials" do
      assert {:ok, %{refresh_token: @mock_refresh_token, refresh_token_expires_at: expires_at}} =
               JQuantsApi.get_refresh_token(@valid_email, @valid_password)

      # 有効期限が未来であることを確認
      assert DateTime.diff(expires_at, DateTime.utc_now()) > 0
    end

    test "returns error with invalid credentials" do
      assert {:error,
              %{status: 400, body: %{"message" => "'mailaddress' or 'password' is incorrect."}}} =
               JQuantsApi.get_refresh_token("wrong@example.com", "wrongpass")
    end

    test "returns error with empty credentials" do
      assert {:error, _} = JQuantsApi.get_refresh_token("", "")
      assert {:error, _} = JQuantsApi.get_refresh_token(nil, nil)
    end
  end

  describe "get_id_token/1" do
    test "returns ID token with valid refresh token" do
      assert {:ok, %{id_token: @mock_id_token, id_token_expires_at: expires_at}} =
               JQuantsApi.get_id_token(@mock_refresh_token)

      # 有効期限が未来であることを確認
      assert DateTime.diff(expires_at, DateTime.utc_now()) > 0
    end

    test "returns error with invalid refresh token" do
      assert {:error,
              %{status: 400, body: %{"message" => "The incoming token is invalid or expired."}}} =
               JQuantsApi.get_id_token("invalid_token")
    end

    test "returns error with empty refresh token" do
      assert {:error, _} = JQuantsApi.get_id_token("")
      assert {:error, _} = JQuantsApi.get_id_token(nil)
    end
  end

  # describe "refresh_tokens/1" do
  #   test "updates both tokens when refresh token is expired" do
  #     # 期限切れのリフレッシュトークンを持つ認証情報を作成
  #     expired_credentials = %Credentials{
  #       email: @valid_email,
  #       password: @valid_password,
  #       refresh_token: "expired_token",
  #       refresh_token_expires_at: DateTime.add(DateTime.utc_now(), -1, :hour),
  #       id_token: "old_id_token",
  #       id_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
  #     }

  #     assert {:ok, updated_credentials} = JQuantsApi.refresh_tokens(expired_credentials)

  #     # 両方のトークンが更新されていることを確認
  #     assert updated_credentials.refresh_token == @mock_refresh_token
  #     assert updated_credentials.id_token == @mock_id_token
  #     assert DateTime.diff(updated_credentials.refresh_token_expires_at, DateTime.utc_now()) > 0
  #     assert DateTime.diff(updated_credentials.id_token_expires_at, DateTime.utc_now()) > 0
  #   end

  #   test "updates only ID token when refresh token is valid" do
  #     # 有効なリフレッシュトークンと期限切れのIDトークンを持つ認証情報を作成
  #     credentials = %Credentials{
  #       email: @valid_email,
  #       password: @valid_password,
  #       refresh_token: @mock_refresh_token,
  #       refresh_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
  #       id_token: "old_id_token",
  #       id_token_expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
  #     }

  #     assert {:ok, updated_credentials} = JQuantsApi.refresh_tokens(credentials)

  #     # IDトークンのみが更新されていることを確認
  #     assert updated_credentials.refresh_token == @mock_refresh_token
  #     assert updated_credentials.id_token == @mock_id_token
  #     assert DateTime.diff(updated_credentials.id_token_expires_at, DateTime.utc_now()) > 0
  #   end

  #   test "returns same credentials when both tokens are valid" do
  #     # 両方のトークンが有効な認証情報を作成
  #     credentials = %Credentials{
  #       email: @valid_email,
  #       password: @valid_password,
  #       refresh_token: @mock_refresh_token,
  #       refresh_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
  #       id_token: @mock_id_token,
  #       id_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
  #     }

  #     assert {:ok, ^credentials} = JQuantsApi.refresh_tokens(credentials)
  #   end

  #   test "returns error when refresh token update fails" do
  #     # 無効なリフレッシュトークンを持つ認証情報を作成
  #     invalid_credentials = %Credentials{
  #       email: "wrong@example.com",
  #       password: "wrongpass",
  #       refresh_token: "invalid_token",
  #       refresh_token_expires_at: DateTime.add(DateTime.utc_now(), -1, :hour),
  #       id_token: "old_id_token",
  #       id_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
  #     }

  #     assert {:error, _} = JQuantsApi.refresh_tokens(invalid_credentials)
  #   end
  # end

  # 型情報を安全に取得
  defp typeof(term) do
    cond do
      is_binary(term) -> "string"
      is_map(term) -> "map#{if Map.has_key?(term, :__struct__), do: " (#{term.__struct__})", else: ""}"
      is_list(term) -> "list"
      is_number(term) -> "number"
      is_atom(term) -> "atom"
      true -> "other: #{inspect(term)}"
    end
  end

  # リクエストボディを適切に解析
  defp parse_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parsed
      _ -> body
    end
  end
  defp parse_body(body), do: body
end
