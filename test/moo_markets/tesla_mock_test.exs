defmodule MooMarkets.TeslaMockTest do
  use MooMarkets.DataCase, async: false

  import Tesla.Mock

  # シンプルなTeslaクライアント
  defmodule TestClient do
    use Tesla

    plug Tesla.Middleware.BaseUrl, "https://example.com/api"
    plug Tesla.Middleware.JSON

    def get_simple, do: get("/simple")
    def post_json(data), do: post("/json", data)
    def post_string(str), do: post("/string", str)
  end

  describe "Tesla.Mock basic behavior" do
    setup do
      # 重要: テスト環境でTesla.Mockをアダプターとして設定
      Application.put_env(:tesla, :adapter, Tesla.Mock)

      # デバッグログファイル
      # File.write!("mock_debug.log", "")

      mock(fn
        %{method: :get, url: "https://example.com/api/simple"} ->
          # log("GET /simple called")
          %Tesla.Env{status: 200, body: %{"message" => "ok"}}

        %{method: :post, url: "https://example.com/api/json", body: body} ->
          # log("POST /json called")
          # log("Body type: #{inspect(typeof(body))}")
          # log("Body: #{inspect(body)}")

          # bodyを適切に処理
          body_data = parse_body(body)
          # log("Parsed body: #{inspect(body_data)}")

          # bodyがマップかどうかを確認
          if is_map(body_data) && Map.has_key?(body_data, "test") do
            %Tesla.Env{status: 200, body: %{"received" => body_data}}
          else
            %Tesla.Env{status: 400, body: %{"error" => "invalid body"}}
          end

        %{method: :post, url: "https://example.com/api/string", body: body} ->
          # log("POST /string called")
          # log("Body type: #{inspect(typeof(body))}")
          # log("Body: #{inspect(body)}")

          # 文字列が渡された場合
          body_str = if is_binary(body), do: body, else: inspect(body)
          %Tesla.Env{status: 200, body: %{"string_length" => String.length(body_str)}}
      end)

      on_exit(fn ->
        # テスト終了後に設定を元に戻す
        Application.delete_env(:tesla, :adapter)
      end)

      :ok
    end

    test "simple GET request" do
      assert {:ok, %{status: 200, body: %{"message" => "ok"}}} = TestClient.get_simple()
    end

    test "POST with JSON data" do
      test_data = %{"test" => "value", "number" => 123}
      assert {:ok, %{status: 200}} = TestClient.post_json(test_data)
    end

    test "POST with invalid JSON data" do
      test_data = %{"invalid" => "no test key"}
      assert {:ok, %{status: 400, body: %{"error" => "invalid body"}}} = TestClient.post_json(test_data)
    end

    test "POST with string data" do
      test_string = "test string"
      assert {:ok, %{status: 200, body: %{"string_length" => 11}}} = TestClient.post_string(test_string)
    end
  end

  # シンプルなログ関数
  # defp log(message) do
  #   File.write!("mock_debug.log", "#{message}\n", [:append])
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
