require "rails_helper"

RSpec.describe User, type: :model do
  let(:user) { User.new(email_address: "student@example.com", password: "Password1!", password_confirmation: "Password1!") }

  it "saves a user and authenticates the hashed password" do
    user.save!
    expect(user.reload.authenticate("Password1!")).to eq(user)
    expect(user.authenticate("incorrect")).to be(false)
    expect(user.password_digest).not_to eq("Password1!")
  end

  it "strips and downcases email addresses before saving" do
    user.email_address = " STUDENT@EXAMPLE.COM "
    user.save!
    expect(user.reload.email_address).to eq("student@example.com")
  end

  [ nil, "", "invalid-address" ].each do |email|
    it "rejects email #{email.inspect}" do
      user.email_address = email
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to be_present
    end
  end

  it "rejects duplicate emails despite case and surrounding spaces" do
    user.save!
    duplicate = User.new(email_address: " STUDENT@EXAMPLE.COM ", password: "Password1!")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email_address]).to include("has already been taken")
  end

  {
    missing: nil, empty: "", too_short: "Aa1!",
    no_uppercase: "password1!", no_lowercase: "PASSWORD1!",
    no_digit: "Password!", no_symbol: "Password1", space_as_symbol: "Password1 ",
    too_many_bytes: "Aa1!" + "é" * 35
  }.each do |reason, password|
    it "rejects a password with #{reason}" do
      invalid_user = User.new(email_address: user.email_address, password: password, password_confirmation: password)
      expect(invalid_user).not_to be_valid
      expect(invalid_user.errors[:password]).to be_present
    end
  end

  it "rejects a mismatched password confirmation" do
    user.password_confirmation = "Different1!"
    expect(user).not_to be_valid
    expect(user.errors[:password_confirmation]).to be_present
  end

  it "allows updating an existing user without resubmitting a password" do
    user.save!
    expect(User.find(user.id).update(email_address: "updated@example.com")).to be(true)
  end

  it "scopes purchases and policies to their owner" do
    user.save!
    other = User.create!(email_address: "other@example.com", password: "Password1!")
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    other_policy = other.store_policies.create!(store_name: "Other Store", window_days: 14)
    purchase = user.purchases.create!(store_policy: policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    other_purchase = other.purchases.create!(store_policy: other_policy, item_name: "Bag", price: 40, purchase_date: Date.new(2026, 1, 1))

    expect(user.purchases).to contain_exactly(purchase)
    expect(user.store_policies).to contain_exactly(policy)
    expect { user.purchases.find(other_purchase.id) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { user.store_policies.find(other_policy.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "destroys owned purchases before policies and removes sessions" do
    user.save!
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    purchase = user.purchases.create!(store_policy: policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    session = user.sessions.create!
    user.destroy!

    expect(User.exists?(user.id)).to be(false)
    expect(Purchase.exists?(purchase.id)).to be(false)
    expect(StorePolicy.exists?(policy.id)).to be(false)
    expect(Session.exists?(session.id)).to be(false)
  end
end
