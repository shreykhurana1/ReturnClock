require "rails_helper"

RSpec.describe "Deadline alert settings", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  def selected_option
    response.parsed_body.at_css("select[name='user[reminder_days_before]'] option[selected]").text
  end

  it "defaults to 2 days before and saves a new lead time" do
    get settings_path
    expect(selected_option).to eq("2 days before")

    patch settings_path, params: { user: { reminder_days_before: 7 } }
    expect(response).to redirect_to(settings_path)
    expect(user.reload.reminder_days_before).to eq(7)
    follow_redirect!
    expect(response.parsed_body.at_css("main").text).to include("Settings updated.")
    expect(selected_option).to eq("1 week before")
  end

  it "rejects a lead time that is not offered" do
    patch settings_path, params: { user: { reminder_days_before: 5 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.reminder_days_before).to eq(2)
  end

  it "ignores other user fields" do
    patch settings_path, params: { user: { reminder_days_before: 3, email_address: "changed@example.com" } }
    expect(user.reload.email_address).to eq("student@example.com")
  end

  it "keeps the setting available but only mentions email when emails are on" do
    get settings_path
    expect(response.parsed_body.at_css("#alerts").text).to include("we email you once")

    allow(Rails.configuration.x).to receive(:reminder_emails_enabled).and_return(false)
    get settings_path
    expect(response.parsed_body.at_css("#alerts select")).to be_present
    expect(response.parsed_body.at_css("#alerts").text).not_to include("email")
  end

  it "turns cards red using the chosen lead time" do
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    user.purchases.create!(store_policy: policy, item_name: "Lamp", price: 20, purchase_date: Date.current - 25)
    get dashboard_path
    expect(response.parsed_body.at_css(".rc-card-top .rc-chip-warning")).to be_present

    user.update!(reminder_days_before: 7)
    get dashboard_path
    expect(response.parsed_body.at_css(".rc-card-top .rc-chip-danger")).to be_present
  end
end
