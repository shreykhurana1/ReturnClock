require "rails_helper"

RSpec.describe "Password reset availability", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }

  context "when password resets are disabled, as in production" do
    before do
      allow(Rails.configuration.x).to receive(:password_resets_enabled).and_return(false)
    end

    it "hides the reset link on the login page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("a[href='#{new_password_path}']")).to be_empty
    end

    it "does not serve the reset request form" do
      get new_password_path
      expect(response).to have_http_status(:not_found)
    end

    it "rejects reset requests without enqueueing mail" do
      expect { post passwords_path, params: { email_address: user.email_address } }
        .not_to have_enqueued_mail(PasswordsMailer, :reset)
      expect(response).to have_http_status(:not_found)
    end

    it "does not serve the password update form even with a valid token" do
      get edit_password_path(user.password_reset_token)
      expect(response).to have_http_status(:not_found)
    end

    it "does not change a password or revoke sessions even with a valid token" do
      session = user.sessions.create!
      expect do
        put password_path(user.password_reset_token), params: { password: "Different1!", password_confirmation: "Different1!" }
      end.not_to change { user.reload.password_digest }
      expect(response).to have_http_status(:not_found)
      expect(session.reload.user).to eq(user)
    end
  end

  it "preserves the built-in reset link in development and test" do
    get new_session_path
    expect(response.parsed_body.css("a[href='#{new_password_path}']")).not_to be_empty
  end
end
