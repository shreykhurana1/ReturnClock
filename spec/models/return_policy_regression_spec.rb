# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Return-policy deadline regressions", type: :model do
  let(:user) { User.create!(email_address: "ryan-policies@example.com", password: "Password1!") }
  let(:short_policy) { user.store_policies.create!(store_name: "Nike", window_days: 14) }
  let(:long_policy) { user.store_policies.create!(store_name: "NIKE", window_days: 30) }
  let(:purchase_date) { Date.new(2026, 11, 1) }

  def new_purchase(policy:, item_name: "Running shoes", date: purchase_date)
    user.purchases.create!(
      store_policy: policy,
      item_name: item_name,
      price: "120.00",
      purchase_date: date
    )
  end

  it "calculates independent deadlines for different windows at the same store" do
    short = new_purchase(policy: short_policy, item_name: "Short-window item")
    long = new_purchase(policy: long_policy, item_name: "Long-window item")

    expect(short.reload.return_by).to eq(Date.new(2026, 11, 15))
    expect(long.reload.return_by).to eq(Date.new(2026, 12, 1))
    expect(user.store_policies.count).to eq(2)
  end

  it "recalculates when switching between two policies for the same store" do
    purchase = new_purchase(policy: short_policy)
    expect(purchase.return_by).to eq(Date.new(2026, 11, 15))

    purchase.update!(store_policy: long_policy)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 12, 1))

    purchase.update!(store_policy: short_policy)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 11, 15))
  end

  it "rejects updating a policy into an existing same-store window without changing records" do
    first = short_policy
    second = long_policy
    original_second_name = second.store_name

    expect(second.update(window_days: first.window_days)).to be(false)
    expect(second.errors[:store_name]).to be_present
    expect(second.reload.window_days).to eq(30)
    expect(second.store_name).to eq(original_second_name)
    expect(user.store_policies.count).to eq(2)
  end

  it "preserves an existing deadline after editing a policy but uses the new window for future purchases" do
    policy = short_policy
    old_purchase = new_purchase(policy: policy, item_name: "Existing item")
    policy.update!(window_days: 21)

    expect(old_purchase.reload.return_by).to eq(Date.new(2026, 11, 15))
    new_item = new_purchase(policy: policy, item_name: "New item")
    expect(new_item.reload.return_by).to eq(Date.new(2026, 11, 22))

    old_purchase.update!(item_name: "Renamed existing item")
    expect(old_purchase.reload.return_by).to eq(Date.new(2026, 11, 15))
  end

  it "uses an edited window when the existing purchase date is subsequently changed" do
    purchase = new_purchase(policy: short_policy)
    short_policy.update!(window_days: 21)

    purchase.update!(purchase_date: Date.new(2026, 11, 2))
    expect(purchase.reload.return_by).to eq(Date.new(2026, 11, 23))
  end

  it "blocks deleting a policy still in use without affecting other same-store policies" do
    protected_policy = short_policy
    alternative = long_policy
    purchase = new_purchase(policy: protected_policy)

    expect(protected_policy.destroy).to be(false)
    expect(protected_policy.reload).to be_persisted
    expect(purchase.reload.store_policy).to eq(protected_policy)
    expect(alternative.reload).to be_persisted
  end

  it "allows deleting a policy after its final associated purchase is deleted" do
    policy = short_policy
    purchase = new_purchase(policy: policy)
    expect(policy.destroy).to be(false)

    purchase.destroy!
    expect { policy.destroy! }.to change(StorePolicy, :count).by(-1)
  end

  it "keeps a past-due date when editing unrelated fields and does not assign urgency" do
    purchase = new_purchase(policy: short_policy, date: Date.new(2026, 1, 1))
    original_deadline = purchase.return_by

    travel_to Time.zone.local(2026, 11, 17, 12) do
      expect(purchase.days_left).to be < 0
      expect(purchase.urgency).to be_nil
      purchase.update!(price: "130.00")
      expect(purchase.reload.return_by).to eq(original_deadline)
      expect(purchase.urgency).to be_nil
    end
  end

  it "honors a user's custom reminder boundary without changing the stored deadline" do
    purchase = new_purchase(policy: short_policy)
    saved_deadline = purchase.return_by
    user.update!(reminder_days_before: 3)

    travel_to Time.zone.local(2026, 11, 11, 12) do
      expect(purchase.days_left).to eq(4)
      expect(purchase.urgency).to eq(:soon)
    end
    travel_to Time.zone.local(2026, 11, 12, 12) do
      expect(purchase.days_left).to eq(3)
      expect(purchase.urgency).to eq(:urgent)
    end
    expect(purchase.reload.return_by).to eq(saved_deadline)
  end
end
