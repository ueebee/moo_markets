defmodule MooMarketsWeb.SchedulerController do
  use MooMarketsWeb, :controller

  alias MooMarkets.Scheduler.Server

  def status(conn, _params) do
    state = Server.get_state()
    render(conn, :status, state: state)
  end
end
