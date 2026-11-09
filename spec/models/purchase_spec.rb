require "rails_helper"

RSpec.describe Purchase, type: :model do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:purchase) do
    user.purchases.build(store_policy: policy, item_name: "Textbook", price: "49.99", purchase_date: Date.new(2026, 1, 15))
  end

  # Keep the example deadlines in the future so open purchases are not expired on save.
  before { travel_to Time.zone.local(2026, 1, 10, 12) }

  it "saves the owner, policy, price, default status, and calculated deadline" do
    purchase.save!
    expect(purchase.reload.user).to eq(user)
    expect(purchase.store_policy).to eq(policy)
    expect(purchase.store_name).to eq("Campus Store")
    expect(purchase.return_window_days).to eq(30)
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

  [ nil, "" ].each do |price|
    it "allows a blank price of #{price.inspect}" do
      purchase.price = price
      expect(purchase).to be_valid
    end
  end

  [ 0, -1, "invalid" ].each do |price|
    it "rejects a price of #{price.inspect}" do
      purchase.price = price
      expect(purchase).not_to be_valid
      expect(purchase.errors[:price]).to be_present
    end
  end

  it "requires a user" do
    purchase.user = nil
    expect(purchase).not_to be_valid
    expect(purchase.errors[:user]).to be_present
  end

  it "saves with only an item name and a return-by date" do
    record = user.purchases.create!(item_name: "Lamp", return_by: Date.new(2026, 3, 1))
    expect(record.store_policy).to be_nil
    expect(record.purchase_date).to be_nil
    expect(record.return_window_days).to be_nil
  end

  it "requires a return-by date, or a purchase date and window" do
    record = user.purchases.build(item_name: "Lamp", purchase_date: Date.new(2026, 1, 15))
    expect(record).not_to be_valid
    expect(record.errors[:base]).to include("Add a return-by date, or a purchase date and return window")
  end

  it "lets a filled-in return-by date win over the window" do
    record = user.purchases.create!(item_name: "Lamp", purchase_date: Date.new(2026, 1, 15),
      return_window_days: 30, return_by: Date.new(2026, 3, 1))
    expect(record.return_by).to eq(Date.new(2026, 3, 1))
    expect(record.return_window_days).to eq(45)
  end

  it "fills the window from a saved store matched without regard to capitalization" do
    policy
    record = user.purchases.create!(item_name: "Lamp", store_name: "campus store", purchase_date: Date.new(2026, 1, 15))
    expect(record.return_by).to eq(Date.new(2026, 2, 14))
    expect(record.store_policy).to eq(policy)
  end

  it "rejects a return-by date before the purchase date and a negative window" do
    record = user.purchases.build(item_name: "Lamp", purchase_date: Date.new(2026, 1, 15), return_by: Date.new(2026, 1, 1))
    expect(record).not_to be_valid
    expect(record.errors.full_messages).to include("Return by can't be before the purchase date")
    record = user.purchases.build(item_name: "Lamp", purchase_date: Date.new(2026, 1, 15), return_window_days: -3)
    expect(record).not_to be_valid
    expect(record.errors.full_messages).to include("Return window can't be negative")
  end

  it "logs a new open purchase with a past deadline as expired" do
    record = user.purchases.create!(item_name: "Boots", return_by: Date.new(2026, 1, 1))
    expect(record.status).to eq("expired")
  end

  it "rejects reopening an expired purchase by status alone" do
    record = user.purchases.create!(item_name: "Boots", return_by: Date.new(2026, 1, 1))
    %w[active returning].each do |status|
      expect(record.update(status: status)).to be(false)
      expect(record.errors[:base]).to include(Purchase::REOPEN_MESSAGE)
      expect(record.reload.status).to eq("expired")
    end
  end

  it "reopens an expired purchase when its return-by date moves to today or later" do
    record = user.purchases.create!(item_name: "Boots", return_by: Date.new(2026, 1, 1))
    record.update!(return_by: Date.new(2026, 1, 10))
    expect(record.reload.status).to eq("active")
  end

  it "lets an expired purchase be settled without a new deadline" do
    record = user.purchases.create!(item_name: "Boots", return_by: Date.new(2026, 1, 1))
    record.update!(status: "shipped_back")
    expect(record.reload.returned_at).to eq(Date.new(2026, 1, 10))
    record.update!(status: "refunded")
    expect(record.reload.refunded_at).to eq(Date.new(2026, 1, 10))
  end

  it "expires overdue active and returning purchases only" do
    open = user.purchases.create!(item_name: "Open", return_by: Date.new(2026, 1, 12))
    returning = user.purchases.create!(item_name: "Returning", return_by: Date.new(2026, 1, 12), status: "returning")
    shipped = user.purchases.create!(item_name: "Shipped", return_by: Date.new(2026, 1, 12), status: "shipped_back")
    due_today = user.purchases.create!(item_name: "Due", return_by: Date.new(2026, 1, 13))
    Purchase.expire_overdue!(Date.new(2026, 1, 13))
    expect([ open, returning, shipped, due_today ].map { |record| record.reload.status })
      .to eq(%w[expired expired shipped_back active])
  end

  %w[active keeping returning shipped_back refund_pending refunded expired].each do |status|
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

  it "recalculates when the window changes" do
    purchase.save!
    purchase.update!(return_window_days: 14)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 1, 29))
  end

  it "uses another saved store's window when the store changes and the deadline is cleared" do
    purchase.save!
    replacement = user.store_policies.create!(store_name: "Other Store", window_days: 14)
    purchase.update!(store_name: "Other Store", return_window_days: nil, return_by: nil)
    expect(purchase.reload.return_by).to eq(Date.new(2026, 1, 29))
    expect(purchase.store_policy).to eq(replacement)
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

  it "keeps its own window when the purchase date changes after a policy edit" do
    purchase.save!
    policy.update!(window_days: 60)
    purchase.reload.update!(purchase_date: Date.new(2026, 2, 1))
    expect(purchase.reload.return_by).to eq(Date.new(2026, 3, 3))
    expect(purchase.store_policy).to eq(policy)
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
    travel_to Time.zone.local(2026, 2, 13, 12)
    expect(purchase.days_left).to eq(1)
    travel_to Time.zone.local(2026, 2, 14, 12)
    expect(purchase.days_left).to eq(0)
    travel_to Time.zone.local(2026, 2, 15, 12)
    expect(purchase.days_left).to eq(-1)
  end

  it "returns no days remaining when the deadline is absent" do
    expect(Purchase.new.days_left).to be_nil
  end
end
