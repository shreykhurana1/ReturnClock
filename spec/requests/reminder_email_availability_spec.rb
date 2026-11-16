require "rails_helper"

RSpec.describe "Reminder email availability", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  context "when reminder emails are disabled, as in production" do
    before do
      allow(Rails.configuration.x).to receive(:reminder_emails_enabled).and_return(false)
    end

    it "lists reminder preferences as planned instead of offering the setting" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("select[name='user[reminder_days_before]']")).to be_empty
      expect(response.parsed_body.at_css("#coming-later").text).to include("Return reminder preferences")
    end

    it "does not accept reminder setting changes" do
      patch settings_path, params: { user: { reminder_days_before: 7 } }
      expect(response).to have_http_status(:not_found)
      expect(user.reload.reminder_days_before).to eq(2)
    end

    it "still expires overdue purchases without sending mail" do
      purchase = user.purchases.create!(item_name: "Lamp", return_by: Date.current + 1)
      ActionMailer::Base.deliveries.clear
      ReminderJob.perform_now(Date.current + 2)
      expect(purchase.reload.status).to eq("expired")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when reminder emails are enabled" do
    it "offers the reminder setting and sends a due reminder" do
      get settings_path
      expect(response.parsed_body.at_css("select[name='user[reminder_days_before]'] option[selected]").text).to eq("2 days before")
      user.purchases.create!(item_name: "Lamp", return_by: Date.current + 2)
      ActionMailer::Base.deliveries.clear
      ReminderJob.perform_now
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ user.email_address ] ])
    end
  end
end
