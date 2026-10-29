require "rails_helper"

RSpec.describe "Authentication forms", type: :request do
  let(:password) { "Password1!" }

  it "serves the authentication CSS referenced by the rendered page" do
    get root_path
    stylesheet = response.parsed_body.at_css("link[rel='stylesheet'][href*='/application']")
    expect(stylesheet).to be_present

    get stylesheet["href"]
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).to include(".auth-landing", ".auth-form-container", ".auth-button")
  end

  it "provides the public landing actions using existing routes" do
    get root_path
    expect(response.parsed_body.at_css("h1").text).to eq("ReturnClock")
    expect(response.parsed_body.at_css("a[href='#{sign_up_path}']").text).to eq("Create Account")
    expect(response.parsed_body.at_css("a[href='#{new_session_path}']").text).to eq("Sign In")
  end

  it "gives each login field a visible label associated with its input" do
    get new_session_path
    %w[email_address password].each do |field|
      input = response.parsed_body.at_css("input[name='#{field}']")
      expect(response.parsed_body.at_css("label[for='#{input['id']}']").text).to be_present
    end
  end

  it "retains email and clears the password after the existing failed-login redirect" do
    User.create!(email_address: "student@example.com", password: password)
    post session_path, params: { email_address: "student@example.com", password: "WrongPassword1!" }
    expect(response).to redirect_to(new_session_path)
    follow_redirect!

    html = response.parsed_body
    expect(html.at_css("input[name='email_address']")["value"]).to eq("student@example.com")
    expect(html.at_css("input[type='password']")["value"]).to be_blank
    expect(html.at_css("#sign-in-error[role='alert']").text).to eq("Try another email address or password.")
    expect(html.at_css("input[name='password']")["aria-describedby"]).to eq("sign-in-error")
  end

  it "places duplicate email errors beside the retained email and clears both passwords" do
    User.create!(email_address: "student@example.com", password: password)
    post sign_up_path, params: { user: { email_address: " STUDENT@EXAMPLE.COM ", password: password, password_confirmation: password } }
    expect(response).to have_http_status(:unprocessable_content)

    html = response.parsed_body
    expect(html.at_css("input[name='user[email_address]']")["value"]).to eq(" STUDENT@EXAMPLE.COM ")
    expect(html.at_css("#email-errors").text).to include("has already been taken")
    expect(html.at_css("input[name='user[email_address]']")["aria-describedby"]).to eq("email-errors")
    expect(html.css("input[type='password']").map { |field| field["value"] }).to all(be_blank)
  end

  it "places password requirements errors beside the password without echoing its value" do
    post sign_up_path, params: { user: { email_address: "student@example.com", password: "password1!", password_confirmation: "password1!" } }
    expect(response).to have_http_status(:unprocessable_content)

    html = response.parsed_body
    expect(html.at_css("#password-errors").text).to include("uppercase")
    expect(html.at_css("#password-hint").text).to eq("At least 8 characters, including uppercase and lowercase letters, a number, and a symbol.")
    expect(html.at_css("input[name='user[password]']")["aria-describedby"].split).to include("password-hint", "password-errors")
    expect(html.css("input[type='password']").map { |field| field["value"] }).to all(be_blank)
  end

  it "places confirmation errors beside confirmation and retains only the email" do
    post sign_up_path, params: { user: { email_address: "student@example.com", password: password, password_confirmation: "Different1!" } }
    expect(response).to have_http_status(:unprocessable_content)

    html = response.parsed_body
    expect(html.at_css("#confirmation-errors").text.strip).to eq("Passwords do not match.")
    expect(html.at_css("input[name='user[email_address]']")["value"]).to eq("student@example.com")
    expect(html.css("input[type='password']").map { |field| field["value"] }).to all(be_blank)
  end

  it "rejects multibyte passwords beyond BCrypt's limit with a concise error" do
    multibyte_password = "Aa1!" + "é" * 35
    expect do
      post sign_up_path, params: { user: { email_address: "student@example.com", password: multibyte_password, password_confirmation: multibyte_password } }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("#password-errors").text).to include("Password is too long. Use a shorter password.")
    expect(response.parsed_body.css("input[type='password']").map { |field| field["value"] }).to all(be_blank)
  end
end
