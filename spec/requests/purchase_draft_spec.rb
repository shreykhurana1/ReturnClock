require "rails_helper"

RSpec.describe "Purchase details during store policy creation", type: :request do
  let(:user) { User.create!(email_address: "draft@example.com", password: "Password1!") }
  let(:details) { { item_name: "Edited textbook", price: "49.99", purchase_date: "2026-11-20", status: "returning" } }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  def start_draft(attributes = details)
    post from_purchase_store_policies_path, params: { purchase: attributes }
    expect(response).to have_http_status(:ok)
    response.parsed_body.at_css("input[name='draft']")["value"]
  end

  def expect_details(attributes = details)
    html = response.parsed_body
    %i[item_name price purchase_date].each do |field|
      expect(html.at_css("input[name='purchase[#{field}]']")["value"]).to eq(attributes.fetch(field))
    end
    expect(html.at_css("select[name='purchase[status]'] option[selected]")["value"]).to eq(attributes.fetch(:status))
  end

  it "preserves a draft through rejected policy inputs, then selects the newly owned policy" do
    previous_policy = user.store_policies.create!(store_name: "Previous store", window_days: 30)
    token = nil
    expect { token = start_draft(details.merge(store_policy_id: previous_policy.id)) }.not_to change(Purchase, :count)
    post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "", window_days: 0 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("[role='alert']").text).to include("Store name can't be blank")
    expect(response.parsed_body.at_css("input[name='draft']")["value"]).to eq(token)

    post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "Book Shop", window_days: 14 } }
    follow_redirect!
    expect_details
    policy = user.store_policies.find_by!(store_name: "Book Shop")
    expect(response.parsed_body.at_css("select[name='purchase[store_policy_id]'] option[selected]")["value"]).to eq(policy.id.to_s)

    post purchases_path, params: { purchase: details.merge(item_name: "", store_policy_id: policy.id) }
    expect(response).to have_http_status(:unprocessable_content)
    expect_details(details.merge(item_name: ""))
    expect { post purchases_path, params: { purchase: details.merge(store_policy_id: policy.id) } }.to change(user.purchases, :count).by(1)
    expect(user.purchases.sole.return_by).to eq(Date.new(2026, 12, 4))
    get new_purchase_path, params: { draft: token }
    expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
  end

  it "returns without creating a policy and consumes the draft exactly once" do
    policy = user.store_policies.create!(store_name: "Existing", window_days: 30)
    token = start_draft(details.merge(store_policy_id: policy.id))
    back = response.parsed_body.css("a").find { |link| link.text == "Back to Add Purchase" }
    expect { get back["href"] }.not_to change { [ Purchase.count, StorePolicy.count ] }
    expect_details
    expect(response.parsed_body.at_css("select option[selected]")["value"]).to eq(policy.id.to_s)
    get new_purchase_path, params: { draft: token }
    expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
  end

  it "does not restore an expired draft" do
    token = start_draft
    travel 31.minutes do
      get new_purchase_path, params: { draft: token }
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
    end
  end

  it "does not reuse a replaced draft or restore one without its token" do
    old = start_draft
    current = start_draft(details.merge(item_name: "Latest"))
    [ old, nil, "forged" ].each do |token|
      get new_purchase_path, params: { draft: token }
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
    end
    get new_purchase_path, params: { draft: current }
    expect_details(details.merge(item_name: "Latest"))
  end

  it "does not restore details after switching accounts or signing in again" do
    other = User.create!(email_address: "other-draft@example.com", password: "Password1!")
    [ user, other ].each do |account|
      token = start_draft
      delete session_path
      post session_path, params: { email_address: account.email_address, password: "Password1!" }
      get new_purchase_path, params: { draft: token }
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
    end
  end

  it "ignores ownership and deadline fields and cannot restore another user's policy" do
    other = User.create!(email_address: "private-draft@example.com", password: "Password1!")
    policy = other.store_policies.create!(store_name: "Private store", window_days: 90)
    token = start_draft(details.merge(user_id: other.id, return_by: "2030-01-01", id: 999, store_policy_id: policy.id))
    get new_purchase_path, params: { draft: token }
    expect_details
    expect(response.body).not_to include("Private store", "2030-01-01")
    expect(response.parsed_body.css("select[name='purchase[store_policy_id]'] option[selected]")).to be_empty
    expect(Purchase.count).to eq(0)
  end

  it "rejects oversized drafts instead of overflowing the session cookie" do
    post from_purchase_store_policies_path, params: { purchase: details.merge(item_name: "x" * 2000) }
    expect(response).to have_http_status(:bad_request)
  end

  it "requires authentication for the handoff" do
    delete session_path
    post from_purchase_store_policies_path, params: { purchase: details }
    expect(response).to redirect_to(new_session_path)
    expect(Purchase.count).to eq(0)
  end

  it "accepts the handoff button's CSRF token and rejects an invalid one" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get new_purchase_path
    button = response.parsed_body.at_css("button[formaction='#{from_purchase_store_policies_path}']")
    post from_purchase_store_policies_path, params: { purchase: details, authenticity_token: button["value"] }
    expect(response).to have_http_status(:ok)
    post from_purchase_store_policies_path, params: { purchase: details, authenticity_token: "invalid" }
    expect(response).to have_http_status(:unprocessable_content)
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
