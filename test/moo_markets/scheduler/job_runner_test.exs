# defmodule MooMarkets.Scheduler.JobRunnerTest do
#   use MooMarkets.DataCase

#   alias MooMarkets.Scheduler.{Job, JobExecution, JobRunner}

#   describe "run_job/1" do
#     setup do
#       job = %Job{
#         name: "Test Job",
#         description: "Test Description",
#         job_type: "listed_companies",
#         schedule: "0 6 * * *",
#         is_enabled: true
#       }
#       |> Repo.insert!()

#       %{job: job}
#     end

#     test "successfully runs a job", %{job: job} do
#       assert :ok = JobRunner.run_job("listed_companies")

#       # Verify job execution was recorded
#       execution = Repo.get_by!(JobExecution, job_id: job.id)
#       assert execution.status == "completed"
#       assert execution.started_at != nil
#       assert execution.completed_at != nil

#       # Verify job was updated
#       updated_job = Repo.get!(Job, job.id)
#       assert updated_job.last_run_at != nil
#     end

#     test "handles job execution failure", %{job: job} do
#       # TODO: Mock ListedCompaniesJob.perform/0 to return error
#       # For now, we'll just test the interface implementation
#       assert :ok = JobRunner.run_job("listed_companies")

#       # Verify job execution was recorded
#       execution = Repo.get_by!(JobExecution, job_id: job.id)
#       assert execution.status == "completed"
#       assert execution.started_at != nil
#       assert execution.completed_at != nil
#     end

#     test "returns error for unknown job type" do
#       assert {:error, :unknown_job_type} = JobRunner.run_job("unknown_job")
#     end

#     test "returns error when job not found" do
#       assert {:error, :job_not_found} = JobRunner.run_job("non_existent_job")
#     end
#   end
# end
