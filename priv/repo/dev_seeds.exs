# Load environment variables from .env file
Dotenv.load!()

# Get credentials from environment variables
email = System.get_env("JQUANTS_EMAIL")
password = System.get_env("JQUANTS_PASSWORD")

if email && password do
  # Create or update credentials using the Auth context
  case MooMarkets.Auth.get_credentials_by_email(email) do
    nil ->
      # Create new credentials
      case MooMarkets.Auth.create_credentials(%{email: email, password: password}) do
        {:ok, credentials} ->
          IO.puts("J-Quants credentials have been created.")
          # Get refresh token and ID token
          with {:ok, refresh_result} <- MooMarkets.Auth.JQuantsApi.get_refresh_token(email, password),
               {:ok, id_result} <- MooMarkets.Auth.JQuantsApi.get_id_token(refresh_result.refresh_token),
               {:ok, _} <- MooMarkets.Auth.update_credentials_tokens(credentials, Map.merge(refresh_result, id_result)) do
            IO.puts("J-Quants tokens have been updated.")
          else
            {:error, reason} ->
              IO.puts("Failed to update tokens: #{inspect(reason)}")
          end
        {:error, reason} ->
          IO.puts("Failed to create credentials: #{inspect(reason)}")
      end
    existing_credentials ->
      # Update existing credentials
      case MooMarkets.Auth.update_credentials(existing_credentials, %{email: email, password: password}) do
        {:ok, credentials} ->
          IO.puts("J-Quants credentials have been updated.")
          # Get refresh token and ID token
          with {:ok, refresh_result} <- MooMarkets.Auth.JQuantsApi.get_refresh_token(email, password),
               {:ok, id_result} <- MooMarkets.Auth.JQuantsApi.get_id_token(refresh_result.refresh_token),
               {:ok, _} <- MooMarkets.Auth.update_credentials_tokens(credentials, Map.merge(refresh_result, id_result)) do
            IO.puts("J-Quants tokens have been updated.")
          else
            {:error, reason} ->
              IO.puts("Failed to update tokens: #{inspect(reason)}")
          end
        {:error, reason} ->
          IO.puts("Failed to update credentials: #{inspect(reason)}")
      end
  end
else
  IO.puts("Warning: JQUANTS_EMAIL and JQUANTS_PASSWORD are not set in .env file.")
end

# Script for populating the database in development environment.

alias MooMarkets.Scheduler.Job
alias MooMarkets.Repo

# 上場企業情報取得ジョブの初期化
%Job{
  name: "上場企業情報取得",
  description: "J-Quants APIから上場企業情報を取得します",
  job_type: "listed_companies",
  schedule: "0 6 * * *",  # 毎日午前6時
  is_enabled: true
}
|> Repo.insert!(
  on_conflict: {:replace, [:name, :description, :schedule, :is_enabled]},
  conflict_target: :job_type
)
