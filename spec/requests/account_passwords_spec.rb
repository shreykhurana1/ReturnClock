require "rails_helper"

RSpec.describe "Account password changes", type: :request do
  let(:password) { "Password1!" }
  let(:new_password) { "Different2!" }
  let(:user) { User.create!(email_address: "account@example.com", password: password) }
  let(:other_user) { User.create!(email_address: "other@example.com", password: "OtherPass2!") }
  let(:attributes) do
    { current_password: password, password: new_password, password_confirmation: new_password }
  end

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def change_password(values = attributes)
    patch settings_password_path, params: { user: values }
  end

  def expect_empty_password_fields
    fields = response.parsed_body.css("main input[type='password']")
    expect(fields.length).to eq(3)
    expect(fields.map { |field| field["value"] }).to all(be_blank)
  end

  it "requires authentication without changing passwords or sessions" do
    user.sessions.create!
    original_digest = user.password_digest
    expect { change_password }.not_to change(Session, :count)
    expect(response).to redirect_to(new_session_path)
    expect(user.reload.password_digest).to eq(original_digest)
  end

  it "keeps the public sign-in and signup links connected without advertising recovery" do
    get root_path
    expect(response.parsed_body.at_css("a[href='#{new_session_path}']").text).to eq("Sign In")
    expect(response.parsed_body.at_css("a[href='#{sign_up_path}']").text).to eq("Create Account")
    get new_session_path
    expect(response.parsed_body.at_css("a[href='#{sign_up_path}']").text).to eq("Create Account")
    expect(response.parsed_body.css("a[href='#{new_password_path}']")).to be_empty
    get sign_up_path
    expect(response.parsed_body.at_css("a[href='#{new_session_path}']").text).to eq("Sign In")
  end

  context "when signed in" do
    before { sign_in }

    it "shows a read-only email and labeled password fields using the existing styling" do
      get settings_path
      html = response.parsed_body
      expect(html.at_css("input[type='email'][readonly]")["value"]).to eq(user.email_address)
      form = html.at_css("main form[action='#{settings_password_path}']")
      expect(form["class"]).to include("rc-purchase-form")
      expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
      { current_password: "Current Password", password: "New Password", password_confirmation: "Confirm New Password" }.each do |field, label|
        input = form.at_css("input[name='user[#{field}]']")
        expect(input["type"]).to eq("password")
        expect(input["autocomplete"]).to eq(field == :current_password ? "current-password" : "new-password")
        expect(form.at_css("label[for='#{input['id']}']").text).to eq(label)
      end
      expect(response.body).to include("Changing your password signs you out on all devices.")
      expect_empty_password_fields
    end

    it "changes the password, revokes every owned session, and requires the new password to sign in" do
      user.sessions.create!
      other_session = other_user.sessions.create!
      previous_cookie = cookies[:session_id]
      original_digest = user.password_digest

      change_password
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_session_path)
      expect(user.reload.password_digest).not_to eq(original_digest)
      expect(user.authenticate(password)).to be(false)
      expect(user.authenticate(new_password)).to eq(user)
      expect(user.sessions).to be_empty
      expect(other_session.reload.user).to eq(other_user)
      expect(cookies[:session_id]).to be_blank
      follow_redirect!
      expect(response.body).to include("Password changed. Please sign in again.")
      expect(response.body).not_to include(password, new_password, user.password_digest)

      cookies[:session_id] = previous_cookie
      get settings_path
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(new_session_path)
      expect(user.sessions).to be_empty
      post session_path, params: { email_address: user.email_address, password: new_password }
      expect(response).to redirect_to(settings_url)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "invalidates a second browser's session cookie" do
      another_browser = ActionDispatch::Integration::Session.new(Rails.application)
      another_browser.post session_path, params: { email_address: user.email_address, password: password }
      another_browser.get dashboard_path
      expect(another_browser.response).to have_http_status(:ok)
      change_password
      another_browser.get dashboard_path
      expect(another_browser.response).to redirect_to(new_session_path)
    end

    it "rejects an incorrect current password and retains existing authentication" do
      digest = user.password_digest
      session_ids = user.sessions.ids
      change_password(attributes.merge(current_password: "WrongPass3!"))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.at_css("#current-password-errors").text).to include("Current password is incorrect.")
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.ids).to eq(session_ids)
      expect(response.body).not_to include("WrongPass3!", new_password, digest)
      expect_empty_password_fields
      get settings_path
      expect(response).to have_http_status(:ok)
    end

    %i[current_password password password_confirmation].each do |field|
      [ :omitted, "", "   ", nil, true ].each do |value|
        it "rejects #{field} when #{value.inspect} without saving or revoking sessions" do
          values = value == :omitted ? attributes.except(field) : attributes.merge(field => value)
          digest = user.password_digest
          session_ids = user.sessions.ids
          change_password(values)
          expect(response).to have_http_status(:unprocessable_content)
          expect(user.reload.password_digest).to eq(digest)
          expect(user.sessions.ids).to eq(session_ids)
          expect(response.parsed_body.at_css("[role='alert']").text).to include("Please correct")
          expect_empty_password_fields
        end
      end
    end

    {
      too_short: "Aa1!", no_uppercase: "different2!", no_lowercase: "DIFFERENT2!",
      no_number: "Different!!", no_symbol: "Different22", whitespace_as_symbol: "Different22 ",
      too_many_bytes: "Aa1!" + "a" * 69, multibyte_limit: "Aa1!" + "é" * 35
    }.each do |reason, invalid_password|
      it "enforces the existing #{reason} password rule" do
        digest = user.password_digest
        session_ids = user.sessions.ids
        change_password(attributes.merge(password: invalid_password, password_confirmation: invalid_password))
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("#new-password-errors").text).to be_present
        expect(user.reload.password_digest).to eq(digest)
        expect(user.sessions.ids).to eq(session_ids)
        expect(response.body).not_to include(invalid_password)
        expect_empty_password_fields
      end
    end

    it "accepts a valid password at BCrypt's 72-byte boundary" do
      boundary = "Aa1!" + "a" * 68
      change_password(attributes.merge(password: boundary, password_confirmation: boundary))
      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate(boundary)).to eq(user)
    end

    it "rejects a confirmation mismatch with a concise field error" do
      digest = user.password_digest
      session_ids = user.sessions.ids
      change_password(attributes.merge(password_confirmation: "Mismatch3!"))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.at_css("#new-password-confirmation-errors").text.strip).to eq("Passwords do not match.")
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.ids).to eq(session_ids)
      expect_empty_password_fields
    end

    it "changes only Current.user and ignores submitted identity and account fields" do
      other_digest = other_user.password_digest
      other_session = other_user.sessions.create!
      patch settings_password_path(user_id: other_user.id), params: { user_id: other_user.id,
        user: attributes.merge(id: other_user.id, user_id: other_user.id, email_address: "changed@example.com", password_digest: "forged") }
      expect(response).to redirect_to(new_session_path)
      expect(user.reload.email_address).to eq("account@example.com")
      expect(user.authenticate(new_password)).to eq(user)
      expect(other_user.reload.password_digest).to eq(other_digest)
      expect(other_session.reload.user).to eq(other_user)
    end

    it "does not accept another account's password as the current password" do
      digest = user.password_digest
      other_digest = other_user.password_digest
      change_password(attributes.merge(current_password: "OtherPass2!", id: other_user.id))
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.password_digest).to eq(digest)
      expect(other_user.reload.password_digest).to eq(other_digest)
    end

    it "returns a bad request for malformed parameters without changing credentials" do
      digest = user.password_digest
      patch settings_password_path, params: { user: "invalid" }
      expect(response).to have_http_status(:bad_request)
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.count).to eq(1)
    end

    it "shows a useful error if a save is rejected without model errors" do
      digest = user.password_digest
      allow_any_instance_of(User).to receive(:update).and_return(false)
      change_password
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Your password could not be changed. Please try again.")
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.count).to eq(1)
      expect_empty_password_fields
    end

    it "rolls back the password if session revocation fails" do
      digest = user.password_digest
      session_ids = user.sessions.ids
      allow_any_instance_of(User).to receive(:sessions).and_raise(ActiveRecord::StatementInvalid, "Session revocation failed")
      expect { change_password }.to raise_error(ActiveRecord::StatementInvalid, "Session revocation failed")
      expect(user.reload.password_digest).to eq(digest)
      expect(Session.where(user_id: user.id).ids).to eq(session_ids)
    end

    it "limits repeated attempts without changing the password or ending the session" do
      digest = user.password_digest
      allow(AccountPasswordsController.cache_store).to receive(:increment).and_return(11)
      change_password
      expect(response).to redirect_to(settings_path)
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.count).to eq(1)
      follow_redirect!
      expect(response.body).to include("Too many password change attempts. Try again later.")
      expect_empty_password_fields
    end

    it "requires CSRF verification when protection is enabled" do
      original_protection = [ SettingsController, AccountPasswordsController ].to_h do |controller|
        [ controller, controller.allow_forgery_protection ]
      end
      original_protection.each_key { |controller| controller.allow_forgery_protection = true }
      get settings_path
      token = response.parsed_body.at_css("main form input[name='authenticity_token']")["value"]
      digest = user.password_digest
      change_password
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.password_digest).to eq(digest)
      expect(user.sessions.count).to eq(1)
      patch settings_password_path, params: { authenticity_token: token, user: attributes }
      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate(new_password)).to eq(user)
    ensure
      original_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
    end

    it "keeps settings protected after signing out to the existing Sign In page" do
      delete session_path
      expect(response).to redirect_to(new_session_path)
      get settings_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
