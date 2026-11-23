require "rails_helper"

RSpec.describe "Purchase return and refund dates", type: :model do
  let(:user) { User.create!(email_address: "dates@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:purchase) { user.purchases.create!(store_policy: policy, item_name: "Boots", price: 80, purchase_date: Date.new(2026, 11, 1)) }

  def on_day(day, status)
    travel_to(Time.zone.local(2026, 11, day, 12)) { purchase.update!(status: status) }
    purchase.reload
  end

  %w[active keeping returning].each do |status|
    it "clears the previous cycle when moving to #{status}" do
      on_day(2, "shipped_back")
      on_day(4, "refunded")
      on_day(6, status)
      expect(purchase).to have_attributes(returned_at: nil, refunded_at: nil, return_by: Date.new(2026, 12, 1))
    end
  end

  it "preserves shipment dates through refund progress and starts a fresh return cycle after reopening" do
    on_day(2, "shipped_back")
    on_day(3, "refund_pending")
    expect(purchase).to have_attributes(returned_at: Date.new(2026, 11, 2), refunded_at: nil)
    on_day(4, "refunded")
    expect(purchase).to have_attributes(returned_at: Date.new(2026, 11, 2), refunded_at: Date.new(2026, 11, 4))
    on_day(6, "active")
    on_day(7, "returning")
    on_day(8, "shipped_back")
    on_day(9, "refund_pending")
    on_day(10, "refunded")
    expect(purchase).to have_attributes(returned_at: Date.new(2026, 11, 8), refunded_at: Date.new(2026, 11, 10))
  end

  it "clears a corrected refund while preserving the known shipment date" do
    on_day(2, "shipped_back")
    on_day(4, "refunded")
    on_day(6, "refund_pending")
    expect(purchase).to have_attributes(returned_at: Date.new(2026, 11, 2), refunded_at: nil)
  end

  it "records the new shipment date and clears the refund when moved back to Shipped Back" do
    on_day(2, "shipped_back")
    on_day(4, "refunded")
    on_day(6, "shipped_back")
    expect(purchase).to have_attributes(returned_at: Date.new(2026, 11, 6), refunded_at: nil)
  end

  %w[refund_pending refunded].each do |status|
    it "does not invent a shipment date when #{status} is recorded directly" do
      on_day(4, status)
      expect(purchase.returned_at).to be_nil
      expect(purchase.refunded_at).to eq(status == "refunded" ? Date.new(2026, 11, 4) : nil)
    end
  end

  it "does not change outcome dates on unrelated edits or unchanged status submissions" do
    on_day(2, "shipped_back")
    on_day(4, "refunded")
    travel_to(Time.zone.local(2026, 11, 6, 12)) { purchase.update!(item_name: "Updated Boots", status: "refunded") }
    expect(purchase.reload).to have_attributes(returned_at: Date.new(2026, 11, 2), refunded_at: Date.new(2026, 11, 4))
  end

  it "does not clear saved dates when an update fails validation" do
    on_day(2, "shipped_back")
    on_day(4, "refunded")
    expect(purchase.update(status: "active", price: -1)).to be(false)
    expect(purchase.reload).to have_attributes(status: "refunded", returned_at: Date.new(2026, 11, 2), refunded_at: Date.new(2026, 11, 4))
  end
end
