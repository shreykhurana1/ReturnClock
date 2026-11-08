require "rails_helper"

# 1. Frontend contract tests: verify presentation and navigation without implementing purchase controllers.
RSpec.describe "Jordan iteration 1 frontend", type: :request do
  let(:password) { "Password1!" }
  let(:user) { User.create!(email_address: "jordan@example.com", password: password) }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  it "keeps the purchase card field contract and shows the purchase date separately" do
    purchase = user.purchases.create!(item_name: "Notebook", price: "59.99",
      purchase_date: Date.current, store_policy: policy, status: "active")
    sign_in
    get dashboard_path

    card = response.parsed_body.at_css(".purchase-card")
    expect(card.at_css("h2").text).to eq("Notebook")
    expect(card.css("dd").size).to eq(5)
    expect(card.css("time[datetime='#{purchase.purchase_date.iso8601}']")).not_to be_empty
    expect(card.css("time[datetime='#{purchase.return_by.iso8601}']")).not_to be_empty
  end

  it "shows six initial cards and puts additional items in an expandable section" do
    7.times do |i|
      user.purchases.create!(item_name: "Purchase #{i}", price: 15,
        purchase_date: Date.current + i, store_policy: policy, status: "active")
    end
    sign_in
    get dashboard_path

    html = response.parsed_body
    expect(html.css(".rc-section > .purchase-grid > .purchase-card").size).to eq(6)
    expect(html.css("details.rc-expand .purchase-card").size).to eq(1)
  end

  it "counts expired purchases separately from refunded, kept and still-actionable purchases" do
    travel_to(Time.zone.local(2026, 11, 7, 12)) do
      %w[refunded keeping].each do |status|
        [ -1, 1 ].each do |days|
          user.purchases.create!(item_name: "#{status} #{days}", price: 15, store_policy: policy,
            purchase_date: Date.current - policy.window_days + days, status: status)
        end
      end
      [ -1, 0, 1 ].each do |days|
        user.purchases.create!(item_name: "active #{days}", price: 15, store_policy: policy,
          purchase_date: Date.current - policy.window_days + days, status: "active")
      end
      user.purchases.create!(item_name: "Returning", price: 15, store_policy: policy,
        purchase_date: Date.current - policy.window_days - 1, status: "returning")
      sign_in
      get history_path

      metrics = response.parsed_body.css(".rc-stat-grid > .card.rc-stat").to_h do |metric|
        [ metric.at_css(".rc-stat-title").text, metric.at_css("strong").text ]
      end
      expect(metrics).to eq("Total history" => "5", "Refunded" => "2", "Keeping" => "2", "Expired" => "1")
      expect(response.parsed_body.css(".purchase-card[data-status='expired']").size).to eq(1)
      response.parsed_body.css(".purchase-card").each do |card|
        expect(card.css("dd").size).to eq(4)
        expect(card.css("dt").map(&:text)).not_to include("Days remaining")
        expect(card.css(".rc-days")).to be_empty
      end
    end
  end

  it "keeps the safe no-submit placeholder until the purchase route exists" do
    sign_in
    get coming_soon_add_purchase_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("main h1").text).to eq("Add Purchase")
    expect(response.parsed_body.css("main form")).to be_empty
    expect(response.parsed_body.at_css("main a[href='#{dashboard_path}']").text).to eq("Back to Dashboard")
  end
end
