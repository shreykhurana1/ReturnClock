require "rails_helper"
require "rake"

RSpec.describe "reminders:run" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("reminders:run")
  end

  let(:task) { Rake::Task["reminders:run"] }
  let(:user) { User.create!(email_address: "someone@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Target", window_days: 30) }

  before do
    task.reenable
    ActionMailer::Base.deliveries.clear
  end

  it "emails reminders that are due today" do
    user.purchases.create!(store_policy: policy, item_name: "Jacket", price: 20, purchase_date: Date.current - 28)
    task.invoke
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ user.email_address ] ])
  end

  it "does nothing when no purchase is due" do
    user.purchases.create!(store_policy: policy, item_name: "Jacket", price: 20, purchase_date: Date.current)
    task.invoke
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
