require "rails_helper"

# Frontend contracts remain in place after purchase backend integration.
RSpec.describe "Dashboard cards and History summaries", type: :request do
  let(:password) { "Password1!" }
  let(:user) { User.create!(email_address: "jordan@example.com", password: password) }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  it "shows the purchase date before the return deadline in the card details" do
    purchase = user.purchases.create!(item_name: "Notebook", price: "59.99",
      purchase_date: Date.current, store_policy: policy, status: "active")
    sign_in
    get dashboard_path

    card = response.parsed_body.at_css(".purchase-card")
    expect(card.at_css("h2").text).to eq("Notebook")
    expect(card.css("dd").size).to eq(4)
    expect(card.css("dt").map(&:text)).to eq([ "Store", "Purchased on", "Return deadline", "Days remaining" ])
    expect(card.css("time[datetime='#{purchase.purchase_date.iso8601}']")).not_to be_empty
    expect(card.css("time[datetime='#{purchase.return_by.iso8601}']")).not_to be_empty
  end

  [ 1, 6, 7 ].each do |count|
    it "shows #{count} purchases in deadline order with at most six initially visible" do
      # Create in reverse deadline order so insertion order cannot satisfy the assertion.
      count.times.to_a.reverse_each do |i|
        user.purchases.create!(item_name: "Purchase #{i}", price: 15,
          purchase_date: Date.current + i, store_policy: policy, status: "active")
      end
      sign_in
      get dashboard_path

      html = response.parsed_body
      expected = count.times.map { |i| "Purchase #{i}" }
      initial = html.css(".rc-section > .purchase-grid > .purchase-card h2").map(&:text)
      additional = html.css("details.rc-expand .purchase-card h2").map(&:text)
      expect(initial).to eq(expected.first(6))
      expect(additional).to eq(expected.drop(6))
      expect(html.css("details.rc-expand").size).to eq(count > 6 ? 1 : 0)
      expect(html.css(".rc-dashboard > .rc-section, .rc-dashboard > .rc-stat-grid").map(&:name)).to eq([ "section", "div" ])
    end
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
        expect(card.css("dd").size).to eq(3)
        expect(card.css("dt").map(&:text)).not_to include("Days remaining")
        expect(card.css(".rc-days")).to be_empty
      end
    end
  end

  it "replaces the placeholder with an authenticated purchase editor" do
    policy
    sign_in
    get coming_soon_add_purchase_path
    expect(response).to redirect_to(new_purchase_path)
    follow_redirect!
    expect(response.parsed_body.at_css("main h1").text).to eq("Add Purchase")
    expect(response.parsed_body.at_css("main form[action='#{purchases_path}']")).to be_present
    expect(response.parsed_body.css("dialog")).to be_empty
  end
end
