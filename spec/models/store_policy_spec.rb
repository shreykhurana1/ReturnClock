require "rails_helper"

RSpec.describe StorePolicy, type: :model do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.build(store_name: "Campus Store", window_days: 30) }

  it "saves a positive return window with its owner" do
    policy.save!
    expect(policy.reload.user).to eq(user)
    expect(policy.window_days).to eq(30)
  end

  [ nil, "", 0, -1, 1.5, "invalid" ].each do |window|
    it "rejects a return window of #{window.inspect}" do
      policy.window_days = window
      expect(policy).not_to be_valid
      expect(policy.errors[:window_days]).to be_present
    end
  end

  [ nil, "", " " ].each do |name|
    it "requires a store name instead of #{name.inspect}" do
      policy.store_name = name
      expect(policy).not_to be_valid
      expect(policy.errors[:store_name]).to be_present
    end
  end

  it "requires an owner" do
    policy.user = nil
    expect(policy).not_to be_valid
    expect(policy.errors[:user]).to be_present
  end

  it "rejects the same store and window for the same owner, ignoring capitalization" do
    policy.save!
    duplicate = user.store_policies.build(store_name: policy.store_name.upcase, window_days: policy.window_days)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:store_name]).to include("already has a policy with that return window")
  end

  it "allows several return windows for the same store" do
    policy.save!
    expect(user.store_policies.create!(store_name: policy.store_name.upcase, window_days: 14)).to be_persisted
  end

  it "labels a policy with its window so a store's policies can be told apart" do
    expect(policy.label).to eq("Campus Store — 30 days")
    expect(policy.tap { |p| p.window_days = 1 }.label).to eq("Campus Store — 1 day")
  end

  it "allows different owners to use the same store name" do
    policy.save!
    other = User.create!(email_address: "other@example.com", password: "Password1!")
    expect(other.store_policies.create!(store_name: policy.store_name.upcase, window_days: policy.window_days)).to be_persisted
  end

  it "prevents deleting a policy that still has purchases" do
    policy.save!
    purchase = user.purchases.create!(store_policy: policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    expect(policy.destroy).to be(false)
    expect(policy.errors[:base]).to be_present
    expect(purchase.reload.store_policy).to eq(policy)
  end

  it "prevents transferring a policy with purchases to a different owner" do
    policy.save!
    user.purchases.create!(store_policy: policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    other = User.create!(email_address: "other@example.com", password: "Password1!")
    expect(policy.update(user: other)).to be(false)
    expect(policy.errors[:user]).to be_present
    expect(policy.reload.user).to eq(user)
  end
end
