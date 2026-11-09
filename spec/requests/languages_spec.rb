require "rails_helper"

RSpec.describe "English-only presentation", type: :request do
  let(:user) { User.create!(email_address: "language@example.com", password: "Password1!") }

  it "defaults to English without a language switch or Chinese locale" do
    get root_path
    html = response.parsed_body
    expect(html.at_css("html")["lang"]).to eq("en")
    expect(html.at_css("main").text).not_to match(/\p{Han}/)
    expect(html.css(".rc-language-switch")).to be_empty
    expect(I18n.available_locales).not_to include(:zh)
  end

  it "ignores former language parameters on public and authenticated pages" do
    get root_path, params: { lang: "zh" }
    expect(response.parsed_body.at_css("html")["lang"]).to eq("en")
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
    { dashboard_path => "Dashboard", history_path => "History", settings_path => "Account Settings" }.each do |path, heading|
      get path, params: { lang: "zh" }
      html = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(html.at_css("html")["lang"]).to eq("en")
      expect(html.at_css("main h1").text).to eq(heading)
      expect(html.at_css("main").text).not_to match(/\p{Han}/)
      expect(html.css(".rc-language-switch")).to be_empty
      expect(html.css("a[href*='lang=']")).to be_empty
    end
  end

  it "uses different active and expired labels even with former language parameters" do
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    [ -1, 0, 1 ].each do |days|
      user.purchases.create!(item_name: "Due #{days}", price: 15,
        purchase_date: Date.current - policy.window_days + days, store_policy: policy, status: "active")
    end
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
    { "en" => [ "Active", "Expired" ], "zh" => [ "Active", "Expired" ] }.each do |lang, labels|
      get dashboard_path, params: { lang: lang }
      cards = response.parsed_body.css(".purchase-card")
      expect(cards.size).to eq(2)
      cards.each do |card|
        expect(card.at_css(".rc-chip").text).to eq(labels.first)
        expect(card.css("dd").last.text).to eq(labels.first)
      end
      get history_path, params: { lang: lang }
      card = response.parsed_body.at_css(".purchase-card")
      expect(card.at_css(".rc-chip").text).to eq(labels.last)
      expect(card.css("dd").last.text).to eq(labels.last)
      expect(card.at_css(".rc-card-bottom > .rc-muted").text).to eq(labels.last)
    end
  end
end
