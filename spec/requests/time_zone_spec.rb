require "rails_helper"

RSpec.describe "Time zone settings", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Zara", window_days: 30) }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  it "defaults to UTC and offers a time zone choice with the alert settings" do
    get settings_path
    expect(user.time_zone).to eq("UTC")
    expect(response.parsed_body.at_css("#alerts select[name='user[time_zone]'] option[selected]").text).to include("UTC")
  end

  it "saves a valid time zone" do
    patch settings_path, params: { user: { time_zone: "Auckland" } }
    expect(response).to redirect_to(settings_path)
    expect(user.reload.time_zone).to eq("Auckland")
  end

  it "rejects a time zone that does not exist" do
    patch settings_path, params: { user: { time_zone: "Mars/Olympus" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.time_zone).to eq("UTC")
  end

  it "keeps the alert lead time when only the time zone changes" do
    user.update!(reminder_days_before: 7)
    patch settings_path, params: { user: { time_zone: "Auckland" } }
    expect(user.reload.reminder_days_before).to eq(7)
  end

  it "classifies a purchase as overdue by the user's local date" do
    purchase = user.purchases.create!(store_policy: policy, item_name: "Coat", price: 20, purchase_date: Date.new(2026, 10, 25))
    expect(purchase.return_by).to eq(Date.new(2026, 11, 24))

    # 23:00 UTC on 24 Nov is already 25 Nov in Auckland (UTC+13), so the deadline has passed there.
    travel_to Time.utc(2026, 11, 24, 23, 0) do
      get dashboard_path
      expect(response.parsed_body.css(".purchase-card h2").map(&:text)).to include("Coat")

      patch settings_path, params: { user: { time_zone: "Auckland" } }
      get dashboard_path
      expect(response.parsed_body.css(".purchase-card h2").map(&:text)).not_to include("Coat")
      get history_path
      expect(response.parsed_body.css(".purchase-card h2").map(&:text)).to include("Coat")
    end
  end
end
