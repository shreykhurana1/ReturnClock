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

  context "when editing an existing purchase" do
    let(:policy) { user.store_policies.create!(store_name: "Original store", window_days: 30) }
    let(:purchase) do
      user.purchases.create!(store_policy: policy, item_name: "Original purchase", price: "20.00",
        purchase_date: Date.new(2026, 11, 1), status: "active")
    end

    def start_edit_draft
      patch from_purchase_store_policies_path, params: { purchase_id: purchase.id, purchase: details }
      expect(response).to have_http_status(:ok)
      response.parsed_body.at_css("input[name='draft']")["value"]
    end

    it "keeps edits through policy validation and selects the new policy without saving the purchase" do
      original = purchase.attributes
      token = start_edit_draft
      post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "", window_days: 0 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.at_css("input[name='draft']")["value"]).to eq(token)
      expect(response.parsed_body.at_css("a[href^='/purchases/']")["href"]).to include(edit_purchase_path(purchase))

      post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "New store", window_days: 14 } }
      new_policy = user.store_policies.find_by!(store_name: "New store")
      expect(response).to redirect_to(edit_purchase_path(purchase, draft: token, store_policy_id: new_policy.id))
      follow_redirect!
      expect_details
      expect(response.parsed_body.at_css("select[name='purchase[store_policy_id]'] option[selected]")["value"]).to eq(new_policy.id.to_s)
      expect(purchase.reload.attributes).to eq(original)

      patch purchase_path(purchase), params: { purchase: details.merge(store_policy_id: new_policy.id) }
      expect(response).to redirect_to(dashboard_path)
      expect(purchase.reload).to have_attributes(item_name: details[:item_name], status: "returning", return_by: Date.new(2026, 12, 4))
      get edit_purchase_path(purchase), params: { draft: token }
      expect(purchase.reload.return_by).to eq(Date.new(2026, 12, 4))
      expect(user.purchases.count).to eq(1)
    end

    it "returns to the same editor with the old policy and unsaved values when policy creation is cancelled" do
      original = purchase.attributes
      patch from_purchase_store_policies_path, params: { purchase_id: purchase.id, purchase: details.merge(store_policy_id: policy.id) }
      back = response.parsed_body.css("a").find { |link| link.text == "Back to Edit Purchase" }
      cancel = response.parsed_body.css("a").find { |link| link.text == "Cancel" }
      expect(cancel["href"]).to eq(back["href"])
      expect(cancel["data-turbo-frame"]).to eq("purchase_editor")
      expect { get cancel["href"] }.not_to change(StorePolicy, :count)
      expect_details
      expect(response.parsed_body.at_css("select[name='purchase[store_policy_id]'] option[selected]")["value"]).to eq(policy.id.to_s)
      expect(purchase.reload.attributes).to eq(original)
    end

    it "rejects restoring an edit draft into a different owned purchase or the new-purchase form" do
      second = user.purchases.create!(store_policy: policy, item_name: "Second purchase", price: 10, purchase_date: Date.current)
      original = second.attributes
      token = start_edit_draft
      [ edit_purchase_path(second), new_purchase_path ].each do |path|
        get path, params: { draft: token }
        expect(response).to have_http_status(:not_found)
      end
      expect(second.reload.attributes).to eq(original)
      get edit_purchase_path(purchase), params: { draft: token }
      expect_details
      # A token cannot populate the editor again after it has been consumed.
      get edit_purchase_path(purchase), params: { draft: token }
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to eq("Original purchase")
    end

    it "does not apply a new-purchase draft to an existing purchase" do
      token = start_draft
      get edit_purchase_path(purchase), params: { draft: token }
      expect(response).to have_http_status(:not_found)
      get new_purchase_path, params: { draft: token }
      expect_details
    end

    it "does not use edit context without a matching draft token" do
      token = start_edit_draft
      get new_store_policy_path, params: { origin: "purchase", draft: "forged" }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.css("a").map(&:text)).not_to include("Back to Edit Purchase")
      expect(response.parsed_body.css("a[href^='/purchases/']")).to be_empty
      get new_store_policy_path, params: { origin: "purchase", draft: token }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("a").map(&:text)).to include("Back to Edit Purchase")
    end

    it "rejects foreign, missing and malformed purchase IDs for either handoff method" do
      other = User.create!(email_address: "foreign-edit@example.com", password: "Password1!")
      other_policy = other.store_policies.create!(store_name: "Private", window_days: 14)
      foreign = other.purchases.create!(store_policy: other_policy, item_name: "Private purchase", price: 10, purchase_date: Date.current)
      original = foreign.attributes
      [ :post, :patch ].each do |method|
        [ foreign.id, 0, "#{purchase.id}junk", "missing" ].each do |id|
          public_send(method, from_purchase_store_policies_path, params: { purchase_id: id, purchase: details })
          expect(response).to have_http_status(:not_found)
        end
      end
      patch from_purchase_store_policies_path, params: { purchase_id: [ purchase.id ], purchase: details }
      expect(response).to have_http_status(:bad_request)
      expect(foreign.reload.attributes).to eq(original)
    end

    it "expires edit drafts and discards them after a new authenticated session" do
      token = start_edit_draft
      travel 31.minutes do
        get edit_purchase_path(purchase), params: { draft: token }
        expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to eq("Original purchase")
        expect do
          post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "Too late", window_days: 14 } }
        end.not_to change(StorePolicy, :count)
        expect(response).to have_http_status(:not_found)
      end
      token = start_edit_draft
      delete session_path
      post session_path, params: { email_address: user.email_address, password: "Password1!" }
      get edit_purchase_path(purchase), params: { draft: token }
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to eq("Original purchase")
    end

    it "does not create a policy if its edit target has been deleted" do
      token = start_edit_draft
      purchase.destroy!
      expect do
        post store_policies_path, params: { origin: "purchase", draft: token, store_policy: { store_name: "Orphan", window_days: 14 } }
      end.not_to change(StorePolicy, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "accepts the edit handoff's PATCH CSRF token and rejects an invalid token" do
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      get edit_purchase_path(purchase)
      button = response.parsed_body.at_css("button[formaction='#{from_purchase_store_policies_path}']")
      patch from_purchase_store_policies_path, params: { purchase_id: purchase.id, purchase: details, authenticity_token: button["value"] }
      expect(response).to have_http_status(:ok)
      patch from_purchase_store_policies_path, params: { purchase_id: purchase.id, purchase: details, authenticity_token: "invalid" }
      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
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
    [ :post, :patch ].each do |method|
      public_send(method, from_purchase_store_policies_path, params: { purchase: details })
      expect(response).to redirect_to(new_session_path)
    end
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
