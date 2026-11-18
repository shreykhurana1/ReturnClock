# frozen_string_literal: true

require "rails_helper"

RSpec.describe Purchase, "status lifecycle regressions", type: :model do
  let(:user) { User.create!(email_address: "ryan-lifecycle@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Nike", window_days: 30) }
  let(:purchase) do
    user.purchases.create!(
      store_policy: policy,
      item_name: "Running shoes",
      price: "120.00",
      purchase_date: Date.new(2026, 11, 1)
    )
  end

  it "preserves the original shipment date while a refund is pending" do
    travel_to Time.zone.local(2026, 11, 10, 12) do
      purchase.update!(status: "shipped_back")
    end
    travel_to Time.zone.local(2026, 11, 13, 12) do
      purchase.update!(status: "refund_pending")
    end

    expect(purchase.reload.status).to eq("refund_pending")
    expect(purchase.returned_at).to eq(Date.new(2026, 11, 10))
    expect(purchase.refunded_at).to be_nil
  end

  it "does not invent a shipment date when refund_pending is selected directly" do
    travel_to Time.zone.local(2026, 11, 13, 12) do
      purchase.update!(status: "refund_pending")
    end

    expect(purchase.reload.returned_at).to be_nil
    expect(purchase.refunded_at).to be_nil
  end

  it "records the refund date without overwriting the original shipment date" do
    travel_to Time.zone.local(2026, 11, 10, 12) do
      purchase.update!(status: "shipped_back")
    end
    travel_to Time.zone.local(2026, 11, 13, 12) do
      purchase.update!(status: "refund_pending")
    end
    travel_to Time.zone.local(2026, 11, 18, 12) do
      purchase.update!(status: "refunded")
    end

    expect(purchase.reload.returned_at).to eq(Date.new(2026, 11, 10))
    expect(purchase.refunded_at).to eq(Date.new(2026, 11, 18))
  end

  it "clears a received refund on re-entering refund_pending but keeps the shipment date" do
    travel_to(Time.zone.local(2026, 11, 10, 12)) { purchase.update!(status: "shipped_back") }
    travel_to(Time.zone.local(2026, 11, 18, 12)) { purchase.update!(status: "refunded") }
    travel_to(Time.zone.local(2026, 11, 19, 12)) { purchase.update!(status: "refund_pending") }

    expect(purchase.reload.returned_at).to eq(Date.new(2026, 11, 10))
    expect(purchase.refunded_at).to be_nil
  end

  %w[active returning keeping].each do |restart_status|
    it "clears both lifecycle dates when switching a refunded purchase to #{restart_status}" do
      travel_to(Time.zone.local(2026, 11, 10, 12)) { purchase.update!(status: "shipped_back") }
      travel_to(Time.zone.local(2026, 11, 18, 12)) { purchase.update!(status: "refunded") }
      purchase.update!(status: restart_status)

      expect(purchase.reload.status).to eq(restart_status)
      expect(purchase.returned_at).to be_nil
      expect(purchase.refunded_at).to be_nil
    end
  end

  it "replaces the shipment date and clears refund date when shipped again" do
    travel_to(Time.zone.local(2026, 11, 10, 12)) { purchase.update!(status: "shipped_back") }
    travel_to(Time.zone.local(2026, 11, 18, 12)) { purchase.update!(status: "refunded") }
    travel_to(Time.zone.local(2026, 11, 20, 12)) { purchase.update!(status: "shipped_back") }

    expect(purchase.reload.returned_at).to eq(Date.new(2026, 11, 20))
    expect(purchase.refunded_at).to be_nil
  end

  it "does not rewrite status timestamps when only the item name changes" do
    travel_to(Time.zone.local(2026, 11, 10, 12)) { purchase.update!(status: "shipped_back") }
    travel_to(Time.zone.local(2026, 11, 18, 12)) { purchase.update!(status: "refunded") }
    travel_to(Time.zone.local(2026, 11, 21, 12)) { purchase.update!(item_name: "Updated shoes") }

    expect(purchase.reload.returned_at).to eq(Date.new(2026, 11, 10))
    expect(purchase.refunded_at).to eq(Date.new(2026, 11, 18))
  end

  it "does not persist an invalid status or alter recorded lifecycle dates" do
    travel_to(Time.zone.local(2026, 11, 10, 12)) { purchase.update!(status: "shipped_back") }
    travel_to(Time.zone.local(2026, 11, 18, 12)) { purchase.update!(status: "refunded") }

    expect(purchase.update(status: "lost_in_transit")).to be(false)
    expect(purchase.reload.status).to eq("refunded")
    expect(purchase.returned_at).to eq(Date.new(2026, 11, 10))
    expect(purchase.refunded_at).to eq(Date.new(2026, 11, 18))
  end
end
