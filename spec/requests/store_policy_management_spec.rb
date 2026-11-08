require "rails_helper"

RSpec.describe "Store policy management", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:other_user) { User.create!(email_address: "other@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:other_policy) { other_user.store_policies.create!(store_name: "Private Store", window_days: 14) }
  let(:purchase) do
    user.purchases.create!(store_policy: policy, item_name: "Textbook", price: 20, purchase_date: Date.current)
  end

  { get: [ "index", "edit" ], patch: [ "update" ], delete: [ "destroy" ] }.each do |method, actions|
    actions.each do |action|
      it "requires authentication for store policy #{action}" do
        path = case action
        when "index" then store_policies_path
        when "edit" then edit_store_policy_path(policy)
        else store_policy_path(policy)
        end
        public_send(method, path, params: { store_policy: { store_name: "Changed" } })
        expect(response).to redirect_to(new_session_path)
        expect(policy.reload.store_name).to eq("Campus Store")
      end
    end
  end

  context "when signed in" do
    before do
      post session_path, params: { email_address: user.email_address, password: "Password1!" }
    end

    { get: "edit", patch: "update", delete: "destroy" }.each do |method, action|
      it "rejects #{action} for another user's policy" do
        original = other_policy.attributes
        path = method == :get ? edit_store_policy_path(other_policy) : store_policy_path(other_policy)
        public_send(method, path, params: { user_id: other_user.id, store_policy: { store_name: "Changed", user_id: user.id } })
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include(other_policy.store_name)
        expect(other_policy.reload.attributes).to eq(original)
      end
    end

    it "lists only owned policies, with creation, editing, and authenticated navigation" do
      policy
      other_policy
      get store_policies_path, params: { user_id: other_user.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Campus Store", "30 days")
      expect(response.body).not_to include("Private Store")
      html = response.parsed_body
      expect(html.at_css("main a[href='#{new_store_policy_path}']").text).to eq("Create Store Policy")
      expect(html.at_css("a[href='#{edit_store_policy_path(policy)}']").text).to eq("Edit Store Policy")
      expect(html.at_css("header a[href='#{store_policies_path}']").text).to eq("Store Policies")
    end

    it "shows an empty state and creation link when the user has no policies" do
      other_policy
      get store_policies_path
      expect(response.body).to include("No store policies yet.")
      expect(response.parsed_body.at_css("main a[href='#{new_store_policy_path}']")).to be_present
      expect(response.body).not_to include("Private Store")
    end

    it "prefills the edit form without any ownership field" do
      get edit_store_policy_path(policy)
      expect(response).to have_http_status(:ok)
      html = response.parsed_body
      expect(html.at_css("input[name='store_policy[store_name]']")["value"]).to eq("Campus Store")
      expect(html.at_css("input[name='store_policy[window_days]']")["value"]).to eq("30")
      expect(html.css("input[name='store_policy[user_id]']")).to be_empty
    end

    it "updates a policy without changing existing deadlines, while new purchases use its new window" do
      deadline = purchase.return_by
      patch store_policy_path(policy), params: { store_policy: { store_name: "Updated Store", window_days: 60 } }
      expect(response).to redirect_to(store_policies_path)
      expect(policy.reload.store_name).to eq("Updated Store")
      expect(policy.window_days).to eq(60)
      expect(purchase.reload.return_by).to eq(deadline)
      post purchases_path, params: { purchase: { item_name: "New Textbook", price: 25,
        purchase_date: Date.current.iso8601, store_policy_id: policy.id } }
      expect(response).to redirect_to(dashboard_path)
      expect(user.purchases.find_by!(item_name: "New Textbook").return_by).to eq(Date.current + 60)
    end

    it "ignores submitted ownership fields" do
      patch store_policy_path(policy), params: { store_policy: { store_name: "Updated Store", user_id: other_user.id } }
      expect(response).to redirect_to(store_policies_path)
      expect(policy.reload.user).to eq(user)
      expect(policy.store_name).to eq("Updated Store")
    end

    [ { store_name: "" }, { window_days: 0 }, { window_days: 1.5 } ].each do |invalid|
      it "renders validation errors without saving #{invalid.inspect}" do
        original = policy.attributes
        patch store_policy_path(policy), params: { store_policy: invalid }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("[role='alert']").text).to include("Please correct")
        expect(policy.reload.attributes).to eq(original)
      end
    end

    it "rejects duplicate names and preserves entered values after validation failure" do
      user.store_policies.create!(store_name: "Other Store", window_days: 14)
      patch store_policy_path(policy), params: { store_policy: { store_name: "Other Store", window_days: 45 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Store name has already been taken")
      html = response.parsed_body
      expect(html.at_css("input[name='store_policy[store_name]']")["value"]).to eq("Other Store")
      expect(html.at_css("input[name='store_policy[window_days]']")["value"]).to eq("45")
      expect(policy.reload.store_name).to eq("Campus Store")
    end

    it "deletes an unused policy while preserving other users' policies" do
      policy
      other_policy
      expect { delete store_policy_path(policy) }.to change(user.store_policies, :count).by(-1)
      expect(response).to redirect_to(store_policies_path)
      expect(StorePolicy.exists?(other_policy.id)).to be(true)
    end

    it "blocks deletion of a referenced policy, shows a useful error, and keeps its purchases" do
      purchase
      expect { delete store_policy_path(policy) }.not_to change(StorePolicy, :count)
      expect(response).to redirect_to(store_policies_path)
      expect(purchase.reload.store_policy).to eq(policy)
      follow_redirect!
      expect(response.parsed_body.at_css("[role='alert']").text).to include("dependent purchases")
      expect(response.body).to include("In use by purchases; cannot be deleted.")
      expect(response.parsed_body.css("main form[action='#{store_policy_path(policy)}']")).to be_empty
    end
  end
end
