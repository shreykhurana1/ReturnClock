require "rails_helper"

RSpec.describe ReminderJob, type: :job do
  let(:user) { User.create!(email_address: "someone@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Target", window_days: 30) }
  let(:today) { Date.new(2026, 12, 28) }

  # Bought on Nov 30 with a 30-day window, so the deadline is Dec 30.
  def add_purchase(owner: user, **attributes)
    owner_policy = owner == user ? policy : owner.store_policies.create!(store_name: "Target", window_days: 30)
    owner.purchases.create!({ store_policy: owner_policy, item_name: "Jacket", price: 20, purchase_date: Date.new(2026, 11, 30) }.merge(attributes))
  end

  def deliveries_to(email)
    ActionMailer::Base.deliveries.select { |mail| mail.to.include?(email) }
  end

  before { ActionMailer::Base.deliveries.clear }

  it "emails once when the deadline is within the owner's lead time" do
    purchase = add_purchase
    described_class.perform_now(today)
    mail = deliveries_to(user.email_address).sole
    expect(mail.subject).to eq("Return Jacket to Target by Dec 30, 2026")
    expect(purchase.reload.reminded_at).to be_present
  end

  it "waits until the lead time is reached" do
    add_purchase
    described_class.perform_now(today - 1)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "follows each user's own lead time" do
    user.update!(reminder_days_before: 7)
    add_purchase
    described_class.perform_now(Date.new(2026, 12, 23))
    expect(deliveries_to(user.email_address).size).to eq(1)
  end

  it "sends each purchase only one reminder" do
    add_purchase
    described_class.perform_now(today)
    described_class.perform_now(today + 1)
    expect(deliveries_to(user.email_address).size).to eq(1)
  end

  it "skips purchases whose deadline has passed" do
    add_purchase
    described_class.perform_now(Date.new(2026, 12, 31))
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  { "active" => 1, "returning" => 1, "keeping" => 0, "shipped_back" => 0, "refund_pending" => 0, "refunded" => 0 }.each do |status, count|
    it "sends #{count} reminder(s) for a #{status} purchase" do
      add_purchase(status: status)
      described_class.perform_now(today)
      expect(ActionMailer::Base.deliveries.size).to eq(count)
    end
  end

  it "emails only the purchase's owner" do
    other = User.create!(email_address: "bob@example.com", password: "Password1!")
    add_purchase
    add_purchase(owner: other, purchase_date: Date.new(2026, 12, 20))
    described_class.perform_now(today)
    expect(deliveries_to(other.email_address)).to be_empty
    expect(deliveries_to(user.email_address).size).to eq(1)
  end

  it "sends nothing when reminder emails are disabled, as in production" do
    allow(Rails.configuration.x).to receive(:reminder_emails_enabled).and_return(false)
    purchase = add_purchase
    described_class.perform_now(today)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(purchase.reload.reminded_at).to be_nil
  end
end
