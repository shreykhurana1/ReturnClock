require "rails_helper"

RSpec.describe "Solid services", type: :model do
  it "shares the application database pool across all three services" do
    [ SolidCache::Record, SolidQueue::Record, SolidCable::Record ].each do |record|
      expect(record.connection_pool).to eq(ActiveRecord::Base.connection_pool)
    end
  end

  it "stores and reads cache entries using the migrated table" do
    cache = SolidCache::Store.new(namespace: "deployment-spec")
    expect(cache.write("ready", "yes")).to be_truthy
    expect(cache.read("ready")).to eq("yes")
  end

  it "durably enqueues an Active Job with a ready execution" do
    stub_const("DeploymentProbeJob", Class.new(ApplicationJob) do
      def perform
      end
    end)
    job = DeploymentProbeJob.new
    ActiveJob::QueueAdapters::SolidQueueAdapter.new.enqueue(job)

    queued_job = SolidQueue::Job.find_by!(active_job_id: job.job_id)
    expect(queued_job.class_name).to eq("DeploymentProbeJob")
    expect(SolidQueue::ReadyExecution.exists?(job_id: queued_job.id)).to be(true)
  end

  it "stores a cable broadcast using the migrated table" do
    SolidCable::Message.broadcast("deployment-spec", "ready")
    expect(SolidCable::Message.find_by!(channel: "deployment-spec").payload).to eq("ready")
  end
end
