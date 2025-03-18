defmodule Mix.Tasks.Jquants.Test do
  use Mix.Task

  @shortdoc "Test J-Quants API client with actual credentials"
  def run(_) do
    Application.ensure_all_started(:tesla)

    [email, password] = System.get_env("B") |> String.split(",")
    IO.puts("Testing with email: #{email}")

    case MooMarkets.Auth.JQuantsApi.get_refresh_token(email, password) do
      {:ok, refresh_result} ->
        IO.puts("Got refresh token: #{refresh_result.refresh_token}")
        IO.puts("Expires at: #{refresh_result.refresh_token_expires_at}")

        case MooMarkets.Auth.JQuantsApi.get_id_token(refresh_result.refresh_token) do
          {:ok, id_result} ->
            IO.puts("\nGot ID token: #{id_result.id_token}")
            IO.puts("Expires at: #{id_result.id_token_expires_at}")

          {:error, error} ->
            IO.puts("\nError getting ID token: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("Error getting refresh token: #{inspect(error)}")
    end
  end
end
