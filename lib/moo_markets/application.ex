defmodule MooMarkets.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MooMarketsWeb.Telemetry,
      MooMarkets.Repo,
      {DNSCluster, query: Application.get_env(:moo_markets, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MooMarkets.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MooMarkets.Finch},
      # Start a worker by calling: MooMarkets.Worker.start_link(arg)
      # {MooMarkets.Worker, arg},
      # Start to serve requests, typically the last entry
      MooMarketsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MooMarkets.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MooMarketsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
