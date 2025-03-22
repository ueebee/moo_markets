defmodule MooMarkets.Scheduler.JobInterface do
  @moduledoc """
  Defines the interface for all scheduler jobs.
  Each job module must implement the callbacks defined here.
  """

  @doc """
  Callback that defines how a job should be executed.
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback perform() :: :ok | {:error, term()}

  @doc """
  Callback that returns a human-readable description of the job.
  """
  @callback description() :: String.t()

  @doc """
  Callback that returns the default schedule for the job in cron format.
  """
  @callback default_schedule() :: String.t()
end
