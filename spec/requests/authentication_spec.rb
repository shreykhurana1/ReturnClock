require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:password) { "Password1!" }
  let(:user) { User.create!(email_address: "student@example.com", password: password) }

  describe "signup" do
    let(:attributes) { { email_address: " NEW@EXAMPLE.COM ", password: password, password_confirmation: password } }

    it "creates a normalized account and signs it in" do
      expect { post sign_up_path, params: { user: attributes } }
        .to change(User, :count).by(1).and change(Session, :count).by(1)
      expect(response).to redirect_to(root_path)
      account = User.find_by!(email_address: "new@example.com")
      expect(account.authenticate(password)).to eq(account)
      expect(account.sessions.count).to eq(1)
      expect(cookies[:session_id]).to be_present

      delete session_path
      expect(response).to have_http_status(:see_other)
      expect(account.sessions.count).to eq(0)
    end

    it "rejects a duplicate normalized email without signing in" do
      user
      attributes[:email_address] = " STUDENT@EXAMPLE.COM "
      expect { post sign_up_path, params: { user: attributes } }
        .not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(Session.count).to eq(0)
      expect(cookies[:session_id]).to be_blank
    end

    {
      email_address: "invalid", password: "weak", password_confirmation: "Mismatch1!"
    }.each do |attribute, value|
      it "rejects invalid #{attribute} without creating an account or session" do
        attributes[attribute] = value
        expect { post sign_up_path, params: { user: attributes } }
          .not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(Session.count).to eq(0)
      end
    end

    it "rejects missing signup parameters" do
      expect { post sign_up_path, params: {} }.not_to change(User, :count)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "login" do
    it "accepts a normalized email and sets a signed HttpOnly SameSite cookie" do
      user
      expect { post session_path, params: { email_address: " STUDENT@EXAMPLE.COM ", password: password } }
        .to change(user.sessions, :count).by(1)
      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
      cookie_header = Array(response.headers["Set-Cookie"]).join("\n")
      expect(cookie_header).to match(/httponly/i)
      expect(cookie_header).to match(/samesite=lax/i)
    end

    [
      { email_address: "student@example.com", password: "Wrong1!" },
      { email_address: "unknown@example.com", password: "Password1!" },
      { email_address: "student@example.com", password: "" },
      { email_address: "", password: "Password1!" },
      {}
    ].each do |credentials|
      it "rejects invalid credentials #{credentials.inspect}" do
        user
        expect { post session_path, params: credentials }.not_to change(Session, :count)
        expect(response).to redirect_to(new_session_path)
        expect(cookies[:session_id]).to be_blank
      end
    end
  end

  describe "logout and authentication protection" do
    it "destroys only the current session and clears its cookie" do
      other_session = user.sessions.create!
      post session_path, params: { email_address: user.email_address, password: password }
      current_session = user.sessions.order(:id).last

      expect { delete session_path }.to change(Session, :count).by(-1)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_blank
      expect(Session.exists?(current_session.id)).to be(false)
      expect(Session.exists?(other_session.id)).to be(true)
    end

    it "redirects an anonymous request without deleting any sessions" do
      user.sessions.create!
      expect { delete session_path }.not_to change(Session, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "rejects a tampered session cookie" do
      post session_path, params: { email_address: user.email_address, password: password }
      cookies[:session_id] = cookies[:session_id] + "tampered"
      expect { delete session_path }.not_to change(Session, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "rejects a replayed cookie after logout" do
      post session_path, params: { email_address: user.email_address, password: password }
      previous_cookie = cookies[:session_id]
      delete session_path
      cookies[:session_id] = previous_cookie
      expect { delete session_path }.not_to change(Session, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "rejects a cookie whose server-side session has been revoked" do
      post session_path, params: { email_address: user.email_address, password: password }
      user.sessions.destroy_all
      expect { delete session_path }.not_to change(Session, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns to the home page after an anonymous non-GET request and login" do
      delete session_path
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "keeps another user's session when the current user logs out" do
      other = User.create!(email_address: "other@example.com", password: password)
      other_session = other.sessions.create!
      post session_path, params: { email_address: user.email_address, password: password }
      delete session_path
      expect(user.sessions.count).to eq(0)
      expect(other.sessions.reload).to contain_exactly(other_session)
    end
  end
end
