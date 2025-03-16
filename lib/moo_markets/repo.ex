defmodule MooMarkets.Repo do
  use Ecto.Repo,
    otp_app: :moo_markets,
    adapter: Ecto.Adapters.Postgres
end
