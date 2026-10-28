require "rails_helper"

RSpec.describe Purchase, type: :model do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:purchase) do
    user.purchases.build(store_policy: policy, item_name: "Textbook", price: "49.99", purchase_date: Date.new(2026, 1, 15))
  end

  it "saves the owner, policy, price, default status, and calculated deadline" do
    purchase.save!
    expect(purchase.reload.user).to eq(user)
    expect(purchase.store_policy).to eq(policy)
    expect(purchase.price).to eq(BigDecimal("49.99"))
    expect(purchase.status).to eq("active")
    expect(purchase.return_by).to eq(Date.new(2026, 2, 14))
  end

  [ nil, "", " " ].each do |name|
    it "requires an item name instead of #{name.inspect}" do
      purchase.item_name = name
      expect(purchase).not_to be_valid
      expect(purchase.errors[:item_name]).to be_present
    end
  end

  [ nil, "", 0, -1, "invalid" ].each do |price|
    it "rejects a price of #{price.inspect}" do
      purchase.price = price
      expect(purchase).not_to be_valid
      expect(purchase.errors[:price]).to be_present
    end
  end

  [ :user, :store_policy, :purchase_date ].each do |attribute|
    it "requires #{attribute}" do
      purchase.public_send("#{attribute}=", nil)
      expect(purchase).not_to be_valid
      expect(purchase.errors[attribute]).to be_present
    end
  end

  it "requires a deadline on an existing purchase" do
    purchase.save!
    purchase.return_by = nil
    expect(purchase).not_to be_valid
    expect(purchase.errors[:return_by]).to be_present
  end

  %w[active keeping returning shipped_back refund_pending refunded].each do |status|
    it "accepts the #{status} status" do
      purchase.status = status
      expect(purchase).to be_valid
    end
  end

  [ nil, "", "unknown" ].each do |status|
    it "rejects status #{status.inspect}" do
      purchase.status = status
      expect(purchase).not_to be_valid
      expect(purchase.errors[:status]).to be_present
    end
  end

  it "calculates across leap day using calendar days" do
    purchase.purchase_date = Date.new(2028, 2, 28)
    purchase.save!
    expect(purchase.reload.return_by).to eq(Date.new(2028, 3, 29))
  end

  it "recalculates when the purchase date changes" do
    purchase.save!
    purchase.update!(purchase_date: Date.new(2026, 12, 20))
    expect(purchase.reload.return_by).to eq(Date.new(2027, 1, 19))
  end

  it "recalculates when the selected policy changes" do
    purchase.save!
    replacement = user.store_policies.create!(store_name: "Other Store", window_days: 14)
    purchase.update!(store_policy: replacement)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 1, 29))
  end

  it "preserves the saved deadline after a policy edit and an unrelated purchase update" do
    purchase.save!
    policy.update!(window_days: 60)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 2, 14))
    purchase.update!(status: "keeping", item_name: "Updated textbook")
    expect(purchase.reload.return_by).to eq(Date.new(2026, 2, 14))
  end

  it "uses the edited policy window for new purchases" do
    policy.update!(window_days: 60)
    purchase.save!
    expect(purchase.reload.return_by).to eq(Date.new(2026, 3, 16))
  end

  it "uses the current saved policy window when the purchase date changes" do
    purchase.save!
    policy.update!(window_days: 60)
    purchase.reload.update!(purchase_date: Date.new(2026, 2, 1))
    expect(purchase.reload.return_by).to eq(Date.new(2026, 4, 2))
  end

  it "rejects another user's policy on creation" do
    other = User.create!(email_address: "other@example.com", password: "Password1!")
    purchase.store_policy = other.store_policies.create!(store_name: "Other Store", window_days: 14)
    expect { purchase.save }.not_to change(Purchase, :count)
    expect(purchase.errors[:store_policy]).to include("must belong to the same user")
  end

  it "rejects switching an existing purchase to another user's policy" do
    purchase.save!
    other = User.create!(email_address: "other@example.com", password: "Password1!")
    other_policy = other.store_policies.create!(store_name: "Other Store", window_days: 14)
    expect(purchase.update(store_policy: other_policy)).to be(false)
    expect(purchase.errors[:store_policy]).to be_present
    expect(purchase.reload.store_policy).to eq(policy)
  end

  it "rejects different unsaved owners even though neither has an id yet" do
    first_owner = User.new(email_address: "first@example.com", password: "Password1!")
    second_owner = User.new(email_address: "second@example.com", password: "Password1!")
    unsaved_policy = second_owner.store_policies.build(store_name: "Other Store", window_days: 14)
    record = first_owner.purchases.build(store_policy: unsaved_policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    expect(record).not_to be_valid
    expect(record.errors[:store_policy]).to include("must belong to the same user")
  end

  it "allows a new purchase and policy with the same unsaved owner" do
    owner = User.new(email_address: "first@example.com", password: "Password1!")
    new_policy = owner.store_policies.build(store_name: "Campus Store", window_days: 14)
    record = owner.purchases.build(store_policy: new_policy, item_name: "Book", price: 20, purchase_date: Date.new(2026, 1, 1))
    expect(record).to be_valid
  end

  it "reports positive, zero, and negative days remaining" do
    purchase.save!
    travel_to Time.zone.local(2026, 2, 13, 12) do
      expect(purchase.days_left).to eq(1)
    end
    travel_to Time.zone.local(2026, 2, 14, 12) do
      expect(purchase.days_left).to eq(0)
    end
    travel_to Time.zone.local(2026, 2, 15, 12) do
      expect(purchase.days_left).to eq(-1)
    end
  end

  it "returns no days remaining when the deadline is absent" do
    expect(Purchase.new.days_left).to be_nil
  end
end
