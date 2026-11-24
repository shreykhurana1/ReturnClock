require "rails_helper"

RSpec.describe "Card quick actions and dashboard totals", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  def add_purchase(status: "active", price: 20, **attributes)
    user.purchases.create!({ store_policy: policy, item_name: "Item #{status}", price: price, purchase_date: Date.current - 5, status: status }.merge(attributes))
  end

  def quick_labels(card)
    card.css("form.rc-quick-action button, form.rc-quick-action input[type='submit']").map { |node| node.text.presence || node["value"] }
  end

  { "active" => [ "Keep it", "Return it" ], "returning" => [ "Sent it back" ], "shipped_back" => [ "Refund received" ],
    "refund_pending" => [ "Refund received" ] }.each do |status, labels|
    it "offers #{labels.to_sentence} on a #{status} purchase" do
      add_purchase(status: status)
      get dashboard_path
      expect(quick_labels(response.parsed_body.at_css(".purchase-card"))).to eq(labels)
    end
  end

  it "offers no quick action once a purchase is decided or overdue" do
    add_purchase(status: "keeping")
    add_purchase(status: "active", item_name: "Overdue", purchase_date: Date.current - 40)
    get history_path
    expect(response.parsed_body.css(".purchase-card").map { |card| quick_labels(card) }).to all(be_empty)
  end

  it "changes the status in one click and records the dates" do
    purchase = add_purchase(status: "returning")
    patch purchase_path(purchase), params: { purchase: { status: "shipped_back" }, quick: 1 }
    expect(response).to redirect_to(dashboard_path)
    expect(purchase.reload).to have_attributes(status: "shipped_back", returned_at: Date.current)

    get dashboard_path
    expect(response.parsed_body.at_css(".rc-outcome").text).to include("Shipped back on")

    patch purchase_path(purchase), params: { purchase: { status: "refunded" }, quick: 1 }
    expect(response).to redirect_to(history_path)
    expect(purchase.reload.refunded_at).to eq(Date.current)
    get history_path
    expect(response.parsed_body.at_css(".rc-outcome").text).to include("Refunded on")
  end

  it "returns to the page with the reason when a quick change is rejected" do
    purchase = add_purchase
    patch purchase_path(purchase), params: { purchase: { status: "bogus" }, quick: 1 }
    expect(response).to redirect_to(dashboard_path)
    expect(purchase.reload.status).to eq("active")
    follow_redirect!
    expect(response.parsed_body.at_css("[role='alert']").text).to include("Status is not included in the list")
  end

  it "replaces the card and totals without navigating for a quick change" do
    purchase = add_purchase
    patch purchase_path(purchase), params: { purchase: { status: "returning" }, quick: 1 },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("action=\"replace\"", "target=\"purchase_#{purchase.id}\"", "dashboard-stats", "Returning",
      "toast-container", "Item active marked as returning.")
    expect(purchase.reload.status).to eq("returning")
  end

  it "removes a completed card without navigating" do
    purchase = add_purchase
    patch purchase_path(purchase), params: { purchase: { status: "keeping" }, quick: 1 },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("action=\"remove\"", "target=\"purchase_#{purchase.id}\"", "dashboard-stats",
      "toast-container", "Item active moved to History.")
    expect(purchase.reload.status).to eq("keeping")
  end

  it "keeps the card and shows the error in place when a quick change is rejected" do
    purchase = add_purchase
    patch purchase_path(purchase), params: { purchase: { status: "bogus" }, quick: 1 },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("target=\"purchase_#{purchase.id}\"", "Status is not included in the list")
    expect(response.body).not_to include("dashboard-stats", "toast-container")
    expect(purchase.reload.status).to eq("active")
  end

  it "shows money at risk for active and returning purchases only" do
    add_purchase(status: "active", price: 20)
    add_purchase(status: "returning", price: 30)
    add_purchase(status: "shipped_back", price: 50)
    get dashboard_path
    stats = response.parsed_body.css(".rc-stat").map(&:text).join(" ")
    expect(stats).to include("Money at risk", "$50.00", "Amount saved")
    expect(stats).not_to include("Tracked purchase value")
  end

  it "describes overdue returns included in Money at risk without changing classification" do
    add_purchase(status: "returning", price: 30, purchase_date: Date.current - 40)
    get dashboard_path
    metric = response.parsed_body.css(".rc-stat").find { |stat| stat.text.include?("Money at risk") }
    expect(metric.at_css("strong").text).to eq("$30.00")
    expect(metric.text).to include("including overdue returns")
  end
end
