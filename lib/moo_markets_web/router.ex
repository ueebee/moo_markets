defmodule MooMarketsWeb.Router do
  use MooMarketsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MooMarketsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MooMarketsWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/credentials", CredentialsLive.Index, :index
    live "/credentials/new", CredentialsLive.Index, :new
    live "/credentials/:id/edit", CredentialsLive.Index, :edit
    live "/credentials/:id", CredentialsLive.Show, :show
    live "/credentials/:id/show/edit", CredentialsLive.Show, :edit
  end

  scope "/api", MooMarketsWeb do
    pipe_through :api

    get "/scheduler/status", SchedulerController, :status
    get "/scheduler/jobs", SchedulerController, :list_jobs
    get "/scheduler/jobs/:id", SchedulerController, :get_job
    put "/scheduler/jobs/:id/enabled", SchedulerController, :toggle_job_enabled
  end

  # Other scopes may use custom stacks.
  # scope "/api", MooMarketsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:moo_markets, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MooMarketsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
