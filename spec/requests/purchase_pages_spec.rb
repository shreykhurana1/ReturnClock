require "rails_helper"

RSpec.describe "Read-only purchase pages", type: :request do
  let(:password) { "Password1!" }
  let(:user) { User.create!(email_address: "student@example.com", password: password) }
  let(:other_user) { User.create!(email_address: "other@example.com", password: password) }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }

  around do |example|
    travel_to(Time.zone.local(2026, 10, 28, 12)) { example.run }
  end

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def create_purchase(name, status:, deadline:)
    user.purchases.create!(store_policy: policy, item_name: name, price: "49.99", status: status,
      purchase_date: deadline - policy.window_days)
  end

  def card_names
    response.parsed_body.css(".purchase-card[data-sample='false'] h2").map(&:text)
  end

  [ "/dashboard", "/history" ].each do |path|
    it "requires authentication for #{path}" do
      get path
      expect(response).to redirect_to(new_session_path)
    end

    it "does not display another user's records on #{path}, even with a forged user_id" do
      other_policy = other_user.store_policies.create!(store_name: "Private Other Store", window_days: 30)
      %w[active keeping refunded returning shipped_back refund_pending].each do |status|
        [ -1, 1 ].each do |days|
          other_user.purchases.create!(store_policy: other_policy, item_name: "Private #{status} #{days}", price: 777,
            status: status, purchase_date: Date.current - 30 + days)
        end
      end
      sign_in
      get path, params: { user_id: other_user.id }
      expect(response).to have_http_status(:ok)
      expect(card_names).to be_empty
      expect(response.body).not_to include("Private Other Store", "Private active", other_user.email_address)
    end
  end

  it "uses the dashboard as the default login destination" do
    sign_in
    expect(response).to redirect_to(dashboard_path)
    follow_redirect!
    expect(response.parsed_body.at_css("h1").text).to eq("Dashboard")
  end

  it "preserves a requested protected History destination through login" do
    get history_path
    sign_in
    expect(response).to redirect_to(history_path)
    follow_redirect!
    expect(response.parsed_body.at_css("h1").text).to eq("History")
  end

  it "redirects signed-in landing page requests to the dashboard" do
    sign_in
    get root_path
    expect(response).to redirect_to(dashboard_path)
  end

  it "keeps the landing page public without the authenticated header" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("header.app-header")).to be_nil
    expect(response.parsed_body.at_css("h1").text).to eq("ReturnClock")
  end

  it "sorts active upcoming returns by nearest deadline, including today" do
    create_purchase("Later return", status: "active", deadline: Date.current + 10)
    create_purchase("Due today", status: "active", deadline: Date.current)
    create_purchase("Sooner return", status: "active", deadline: Date.current + 2)
    sign_in
    get dashboard_path
    expect(card_names).to eq([ "Due today", "Sooner return", "Later return" ])
  end

  it "separates expired active and completed purchases from the dashboard" do
    create_purchase("Expired active", status: "active", deadline: Date.current - 1)
    create_purchase("Kept early", status: "keeping", deadline: Date.current + 5)
    create_purchase("Refunded early", status: "refunded", deadline: Date.current + 6)
    sign_in
    get dashboard_path
    expect(card_names).to be_empty
    expect(response.body).to include("No actionable purchases yet.")

    get history_path
    expect(card_names).to contain_exactly("Expired active", "Kept early", "Refunded early")
  end

  %w[returning shipped_back refund_pending].each do |status|
    it "keeps #{status} purchases actionable before, on, and after their deadlines" do
      [ -1, 0, 1 ].each do |days|
        create_purchase("#{status} #{days}", status: status, deadline: Date.current + days)
      end
      sign_in
      get dashboard_path
      expect(card_names).to eq([ "#{status} -1", "#{status} 0", "#{status} 1" ])
      get history_path
      expect(card_names).to be_empty
    end
  end

  it "does not classify active purchases due today or later as expired" do
    create_purchase("Today", status: "active", deadline: Date.current)
    create_purchase("Tomorrow", status: "active", deadline: Date.current + 1)
    sign_in
    get history_path
    expect(card_names).to be_empty
  end

  it "shows only the signed-in user's records in each page" do
    create_purchase("Own upcoming", status: "active", deadline: Date.current + 1)
    create_purchase("Own history", status: "keeping", deadline: Date.current - 1)
    sign_in
    get dashboard_path
    expect(card_names).to eq([ "Own upcoming" ])
    get history_path
    expect(card_names).to eq([ "Own history" ])
  end

  it "displays every required purchase field in a card" do
    create_purchase("Textbook", status: "active", deadline: Date.current + 2)
    sign_in
    get dashboard_path
    card = response.parsed_body.at_css(".purchase-card")
    expect(card.at_css("h2").text).to eq("Textbook")
    expect(card.css("dd").map(&:text)).to eq([ "Campus Store", "$49.99", "October 30, 2026", "2", "Active" ])
    expect(card.at_css("time")["datetime"]).to eq("2026-10-30")
  end

  [ "/dashboard", "/history" ].each do |path|
    it "provides working authenticated navigation and a profile menu on #{path}" do
      sign_in
      get path
      nav = response.parsed_body.at_css("nav[aria-label='Main navigation']")
      expect(nav.css("a").map { |link| link["href"] }).to include(dashboard_path, history_path)
      expect(nav.at_css("details.profile-menu").text).to include(user.email_address, "Sign Out")
      sign_out_form = nav.at_css("form[action='#{session_path}']")
      expect(sign_out_form.at_css("input[name='_method']")["value"]).to eq("delete")
      expect(nav.css("a").map(&:text)).not_to include("Add Purchase")
      expect(nav.at_css("a[href='#{settings_path}']").text).to eq("Account Settings")
      expect(nav.css("a").map(&:text)).not_to include("Change Password")
      expect(response.parsed_body.css("a[href='#{new_password_path}']")).to be_empty
    end

    it "rejects write requests to the read-only #{path} route" do
      sign_in
      post path
      expect(response).to have_http_status(:not_found)
    end
  end

  it "renders a demo for empty accounts without creating purchases" do
    sign_in
    expect do
      get dashboard_path
      expect(response.body).to include("Demo preview")
      get history_path
      expect(response.body).to include("Demo preview")
    end.not_to change(Purchase, :count)
  end
end
