require "rails_helper"

RSpec.describe "Merged frontend workflow safeguards", type: :request do
  let(:user) { User.create!(email_address: "review@example.com", password: "Password1!") }
  let(:other_user) { User.create!(email_address: "private@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }

  around do |example|
    travel_to(Time.zone.local(2026, 11, 9, 12)) { example.run }
  end

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  def create_purchase(status, days_left: -1)
    user.purchases.create!(item_name: "My #{status} #{days_left}", price: 20, store_policy: policy,
      status: status, purchase_date: Date.current - policy.window_days + days_left)
  end

  it "provides History filters matching only the owner's completed and expired cards" do
    Purchase::STATUSES.each { |status| create_purchase(status) }
    create_purchase("active", days_left: 0)
    other_policy = other_user.store_policies.create!(store_name: "Private Store", window_days: 30)
    other_user.purchases.create!(item_name: "Private purchase", price: 20, store_policy: other_policy,
      status: "keeping", purchase_date: Date.current)

    get history_path, params: { user_id: other_user.id }
    html = response.parsed_body
    filters = html.css("button[data-rc-purchase-filter-value]")
    expect(filters.map { |button| button["data-rc-purchase-filter-value"] }).to contain_exactly("all", "keeping", "refunded", "expired")
    expect(filters.select { |button| button["aria-pressed"] == "true" }.map(&:text)).to eq([ "All" ])
    cards = html.css(".purchase-card")
    expect(cards.to_h { |card| [ card.at_css("h2").text, card["data-status"] ] }).to eq(
      "My active -1" => "expired", "My returning -1" => "expired", "My expired -1" => "expired",
      "My keeping -1" => "keeping", "My refunded -1" => "refunded")
    expect(response.body).not_to include("Private purchase", "Private Store")
    cards.each do |card|
      expect(card["data-rc-purchase-filter-target"]).to eq("card")
      options = card.css(".rc-status-mini-form option").map { |option| option["value"] }
      expect(options).to eq(Purchase::STATUSES)
    end
    expired_select = html.at_css("[data-status='expired'] .rc-status-mini-form select")
    expect(expired_select.at_css("option[selected]")["value"]).to eq("expired")

    get dashboard_path
    expect(response.parsed_body.css(".purchase-card").map { |card| card["data-status"] })
      .to contain_exactly("active", "shipped_back", "refund_pending")
  end

  it "rejects a status-only update to another user's purchase, including forged ownership fields" do
    other_policy = other_user.store_policies.create!(store_name: "Private Store", window_days: 30)
    purchase = other_user.purchases.create!(item_name: "Private purchase", price: 20,
      store_policy: other_policy, purchase_date: Date.current)
    original = purchase.attributes
    patch purchase_path(purchase), params: { purchase: { status: "refunded", user_id: user.id } }
    expect(response).to have_http_status(:not_found)
    expect(purchase.reload.attributes).to eq(original)
  end

  it "requires a valid CSRF token for the quick status form when forgery protection is enabled" do
    purchase = create_purchase("active", days_left: 1)
    original_protection = [ DashboardController, PurchasesController ].to_h do |controller|
      [ controller, controller.allow_forgery_protection ]
    end
    original_protection.each_key { |controller| controller.allow_forgery_protection = true }
    get dashboard_path
    form = response.parsed_body.at_css(".rc-status-mini-form")
    expect(form["action"]).to eq(purchase_path(purchase))
    expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
    token = form.at_css("input[name='authenticity_token']")["value"]
    expect(token).to be_present

    patch purchase_path(purchase), params: { purchase: { status: "keeping" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(purchase.reload.status).to eq("active")

    patch purchase_path(purchase), params: { authenticity_token: token, purchase: { status: "keeping" } }
    expect(response).to redirect_to(history_path)
    expect(purchase.reload.status).to eq("keeping")
  ensure
    original_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  it "keeps password changes unavailable in Account Settings" do
    get settings_path
    html = response.parsed_body
    expect(html.at_css("main").text).to include("Password changes are not available", "Not available yet")
    expect(html.at_css("input[type='email'][readonly]")["value"]).to eq(user.email_address)
    expect(html.css("main input[type='password']")).to be_empty
    expect(html.css("main form").map { |form| form["action"] }).to eq([ settings_path ])
  end

  it "filters current and new password parameters from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("user" => { "current_password" => "Password1!", "password" => "Changed1!",
      "password_confirmation" => "Changed1!" })
    expect(filtered.fetch("user").values).to all(eq("[FILTERED]"))
  end

  %i[post patch put].each do |method|
    it "does not accept #{method} password changes through the settings URL" do
      original = user.password_digest
      public_send(method, settings_path, params: { user_id: other_user.id,
        user: { current_password: "Password1!", password: "Changed1!", password_confirmation: "Changed1!" } })
      # PATCH saves reminder settings only, so password fields are a bad request.
      expect(response).to have_http_status(method == :patch ? :bad_request : :not_found)
      expect(user.reload.password_digest).to eq(original)
      expect(user.authenticate("Password1!")).to eq(user)
      expect(user.authenticate("Changed1!")).to be(false)
    end
  end
end
