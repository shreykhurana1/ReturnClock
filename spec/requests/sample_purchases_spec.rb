require "rails_helper"

RSpec.describe "Sample purchases for empty accounts", type: :request do
  it "shows examples after signup with demo totals and preview actions without saving purchases" do
    post sign_up_path, params: { user: { email_address: "new-shopper@example.com",
      password: "Password1!", password_confirmation: "Password1!" } }
    expect(response).to redirect_to(dashboard_path)

    expect do
      { dashboard_path => %w[active], history_path => %w[refunded keeping expired] }.each do |path, statuses|
        get path
        html = response.parsed_body
        cards = html.css(".purchase-card[data-sample='true']")
        expect(cards.size).to eq(path == dashboard_path ? 7 : 3)
        expect(cards.map { |card| card["data-status"] }.uniq).to match_array(statuses)
        preview_enabled = %i[new_purchase_path edit_purchase_path purchase_path].any? do |route|
          !Rails.application.routes.url_helpers.respond_to?(route)
        end
        expect(cards.css("button[data-action='rc-purchase-preview#edit']").size).to eq(preview_enabled ? cards.size : 0)
        expect(cards.css("form")).to be_empty
        expect(html.css(".rc-empty")).to be_empty
        expect(html.css(".rc-stat strong").first.text).to eq(path == dashboard_path ? "7" : "3")
        expect(html.text).to include("not saved to your account")
      end
    end.not_to change { [ Purchase.count, StorePolicy.count ] }
  end

  it "hides examples on both pages once the account has any real purchase" do
    user = User.create!(email_address: "shopper@example.com", password: "Password1!")
    policy = user.store_policies.create!(store_name: "My Store", window_days: 30)
    user.purchases.create!(store_policy: policy, item_name: "My purchase", price: 10,
      purchase_date: Date.current, status: "active")
    post session_path, params: { email_address: user.email_address, password: "Password1!" }

    [ dashboard_path, history_path ].each do |path|
      get path
      expect(response.parsed_body.css(".rc-sample-notice")).to be_empty
    end
  end

  it "keeps samples and preview actions English even with a former Chinese language parameter" do
    user = User.create!(email_address: "sample-language@example.com", password: "Password1!")
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
    get dashboard_path, params: { lang: "zh" }
    html = response.parsed_body
    expect(html.at_css(".rc-sample-notice").text).to include("Demo preview", "not saved")
    expect(html.at_css(".purchase-card h2").text).to eq("Wireless Headphones")
    expect(html.at_css(".rc-product-store").text).to eq("Campus Store")
    expect(html.at_css(".rc-card-actions").text).to include("Edit")
    expect(html.css(".rc-language-switch")).to be_empty
    expect(html.at_css("main").text).not_to match(/\p{Han}/)

    get history_path, params: { lang: "zh" }
    expect(response.parsed_body.css(".rc-product-name").map(&:text)).to eq([ "Bluetooth Speaker", "Travel Mug", "Wireless Mouse" ])
    expect(response.parsed_body.css(".rc-chip").map(&:text)).to eq([ "Refunded", "Keeping", "Expired" ])

    get dashboard_path
    expect(response.parsed_body.at_css(".purchase-card h2").text).to eq("Wireless Headphones")
    expect(response.parsed_body.at_css("main").text).not_to match(/\p{Han}/)
  end
end
