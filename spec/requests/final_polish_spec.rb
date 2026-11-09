require "rails_helper"

RSpec.describe "Purchase status and navigation", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:attributes) do
    { item_name: "Textbook", price: "49.99", purchase_date: Date.current.iso8601, store_policy_id: policy.id }
  end

  around do |example|
    travel_to(Time.zone.local(2026, 11, 9, 12)) { example.run }
  end

  before do
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
  end

  it "offers all six statuses when adding a purchase, defaulting to Active with a short explanation" do
    policy
    get new_purchase_path
    select = response.parsed_body.at_css("select[name='purchase[status]']")
    expect(select.css("option").map { |option| option["value"] }).to eq(Purchase::STATUSES)
    expect(select.css("option").map(&:text)).to eq([ "Active", "Keeping", "Returning", "Shipped Back", "Refund Pending", "Refunded" ])
    expect(select.at_css("option[selected]")["value"]).to eq("active")
    expect(response.body).to include("Active means you haven't decided whether to keep or return this purchase.")
  end

  Purchase::STATUSES.each do |status|
    it "saves #{status} during creation and shows it on the correct page" do
      post purchases_path, params: { purchase: attributes.merge(status: status) }
      destination = %w[keeping refunded].include?(status) ? history_path : dashboard_path
      expect(response).to redirect_to(destination)
      purchase = user.purchases.sole
      expect(purchase.status).to eq(status)
      expect(purchase.return_by).to eq(Date.current + 30)
      follow_redirect!
      expect(response.parsed_body.at_css(".purchase-card h2").text).to eq("Textbook")
      get(destination == dashboard_path ? history_path : dashboard_path)
      expect(response.parsed_body.css(".purchase-card")).to be_empty
    end
  end

  %w[returning shipped_back refund_pending].each do |status|
    it "keeps a newly recorded expired #{status} purchase on Dashboard" do
      post purchases_path, params: { purchase: attributes.merge(status: status, purchase_date: (Date.current - 40).iso8601) }
      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.parsed_body.at_css(".purchase-card h2").text).to eq("Textbook")
    end
  end

  it "retains the selected status and fields when purchase validation fails" do
    post purchases_path, params: { purchase: attributes.merge(status: "keeping", price: -1) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.purchases).to be_empty
    expect(response.parsed_body.at_css("select[name='purchase[status]'] option[selected]")["value"]).to eq("keeping")
    expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to eq("Textbook")
  end

  Purchase::STATUSES.each do |status|
    it "cancels deletion of #{status} back to the page that contains it, ignoring return URLs" do
      purchase = user.purchases.create!(attributes.merge(status: status))
      get confirm_delete_purchase_path(purchase), params: { return_to: "https://example.org/" }
      destination = %w[keeping refunded].include?(status) ? history_path : dashboard_path
      cancel = response.parsed_body.css("main a").find { |link| link.text == "Cancel" }
      expect(cancel["href"]).to eq(destination)
      expect(Purchase.exists?(purchase.id)).to be(true)
      get cancel["href"]
      expect(response.parsed_body.at_css(".purchase-card h2").text).to eq("Textbook")
    end
  end

  it "cancels deletion of an expired active purchase back to History" do
    purchase = user.purchases.create!(attributes.merge(purchase_date: Date.current - 40))
    get confirm_delete_purchase_path(purchase)
    expect(response.parsed_body.at_css("main a[href='#{history_path}']").text).to eq("Cancel")
  end

  it "returns a policy created from management to the policy list" do
    get new_store_policy_path
    expect(response.parsed_body.css("input[name='origin']")).to be_empty
    post store_policies_path, params: { store_policy: { store_name: "Campus Store", window_days: 30 } }
    expect(response).to redirect_to(store_policies_path)
    follow_redirect!
    expect(response.parsed_body.at_css("main h1").text).to eq("Store Policies")
    expect(response.body).to include("Campus Store")
  end

  it "preserves purchase context on validation failure and returns with the new policy selected" do
    get new_store_policy_path, params: { origin: "purchase" }
    expect(response.parsed_body.at_css("input[name='origin']")["value"]).to eq("purchase")
    post store_policies_path, params: { origin: "purchase", store_policy: { store_name: "Campus Store", window_days: 0 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("input[name='origin']")["value"]).to eq("purchase")
    post store_policies_path, params: { origin: "purchase", store_policy: { store_name: "Campus Store", window_days: 30 } }
    expect(response).to redirect_to(new_purchase_path(store_policy_id: user.store_policies.sole.id))
    follow_redirect!
    expect(response.parsed_body.at_css("select[name='purchase[store_policy_id]'] option[selected]").text).to eq("Campus Store")
  end

  [ "https://example.org/", "//example.org/", "/settings" ].each do |origin|
    it "ignores unrecognized policy origins and arbitrary return URLs: #{origin}" do
      post store_policies_path, params: { origin: origin, return_to: origin, store_policy: { store_name: "Campus Store", window_days: 30 } }
      expect(response).to redirect_to(store_policies_path)
    end
  end

  it "retains the accessible profile controls with the requested account content" do
    get dashboard_path
    menu = response.parsed_body.at_css("details.profile-menu")
    expect(menu.at_css("summary[aria-label='Profile menu']")).to be_present
    content = menu.at_css(".profile-menu-content")
    expect(content.at_css("p.profile-account-label").text).to eq("Account")
    expect(content.at_css("p.auth-hint").text).to eq(user.email_address)
    expect(content.at_css("hr")).to be_present
    expect(content.at_css("a[href='#{settings_path}']").text).to eq("Account Settings")
    expect(content.css("span[aria-hidden='true']").length).to eq(2)
    expect(content.at_css("form[action='#{session_path}'] button").text).to eq("Sign Out")
  end
end
