require "rails_helper"

RSpec.describe "Navigation placeholders", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
  end

  { "/coming-soon/add-purchase" => "Add Purchase", "/settings" => "Account Settings" }.each do |path, heading|
    it "requires authentication for #{path}" do
      get path
      expect(response).to redirect_to(new_session_path)
    end

    it "renders #{heading} with the shared header and a working Dashboard link" do
      sign_in
      get path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("main h1").text).to eq(heading)
      expect(response.parsed_body.at_css("header.app-header")).to be_present
      expect(response.parsed_body.at_css("main a[href='#{dashboard_path}']").text).to eq("Back to Dashboard")
      expect(response.parsed_body.at_css("main").text).to include("coming soon")
      expect(response.parsed_body.css("main form")).to be_empty
    end
  end

  it "shows only the signed-in email in settings, even if another user_id is supplied" do
    other_user = User.create!(email_address: "other@example.com", password: "Password1!")
    sign_in
    get settings_path, params: { user_id: other_user.id }
    expect(response.parsed_body.at_css("main").text).to include(user.email_address)
    expect(response.body).not_to include(other_user.email_address)
  end

  it "keeps Account Settings in navigation and the purchase entry in the Dashboard content" do
    sign_in
    [ dashboard_path, history_path, coming_soon_add_purchase_path, settings_path ].each do |path|
      get path
      nav = response.parsed_body.at_css("nav[aria-label='Main navigation']")
      add_purchase_path = if Rails.application.routes.url_helpers.respond_to?(:new_purchase_path)
        Rails.application.routes.url_helpers.new_purchase_path
      else
        coming_soon_add_purchase_path
      end
      expect(nav.css("a[href='#{add_purchase_path}']")).to be_empty
      if path == dashboard_path
        expect(response.parsed_body.at_css("main a[href='#{add_purchase_path}']").text).to include("Add Purchase")
      end
      expect(nav.at_css("details a[href='#{settings_path}']").text).to eq("Account Settings")
      expect(nav.at_css("form[action='#{session_path}'] button").text).to eq("Sign Out")
    end
  end

  it "does not provide purchase creation or settings update actions" do
    sign_in
    expect { post coming_soon_add_purchase_path, params: { purchase: { item_name: "Should not be created" } } }
      .not_to change(Purchase, :count)
    expect(response).to have_http_status(:not_found)

    expect { patch settings_path, params: { user: { email_address: "changed@example.com" } } }
      .not_to change { user.reload.email_address }
    expect(response).to have_http_status(:not_found)
  end
end
