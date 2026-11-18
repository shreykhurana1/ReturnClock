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
      window = html.at_css(".rc-policy-window")
      expect(window.at_css("span").text).to eq("Return window")
      expect(window.at_css("strong").text).to eq("30 days")
      expect(window.text.scan(/\b30\b/).size).to eq(1)
      expect(html.at_css("main a[href='#{new_store_policy_path}']").text).to eq("Create Store Policy")
      expect(html.at_css("main a[href='#{new_store_policy_path}']")["data-turbo-frame"]).to eq("purchase_editor")
      expect(html.css("main a[href='#{new_purchase_path}']")).to be_empty
      expect(html.at_css("a[href='#{edit_store_policy_path(policy)}']").text).to eq("Edit")
      expect(html.at_css("form[action='#{store_policy_path(policy)}'] button").text).to eq("Delete")
      expect(html.at_css("form[action='#{store_policy_path(policy)}'] button")["class"]).to include("rc-btn-outline")
      expect(html.at_css("a[href='#{edit_store_policy_path(policy)}']")["data-turbo-frame"]).to eq("purchase_editor")
      expect(html.css("dialog.rc-purchase-modal turbo-frame#purchase_editor").size).to eq(1)
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

    it "opens policy creation in the shared dialog with cancel and list-refresh behavior" do
      get new_store_policy_path, headers: { "Turbo-Frame" => "purchase_editor" }
      expect(response).to have_http_status(:ok)
      frame = response.parsed_body.at_css("turbo-frame#purchase_editor")
      expect(frame.at_css("h1").text).to eq("Create Store Policy")
      expect(frame.at_css("form")["data-modal-save"]).to eq("true")
      expect(frame.at_css("a[data-modal-dismiss][href='#{store_policies_path}']")).to be_present

      get new_store_policy_path, params: { origin: "purchase" }, headers: { "Turbo-Frame" => "purchase_editor" }
      expect(response.parsed_body.at_css("turbo-frame#purchase_editor form")["data-modal-save"]).to eq("false")
    end

    it "keeps invalid policy creation and entered values in the dialog" do
      expect do
        post store_policies_path, headers: { "Turbo-Frame" => "purchase_editor" },
          params: { store_policy: { store_name: "New Store", window_days: 0 } }
      end.not_to change(StorePolicy, :count)
      expect(response).to have_http_status(:unprocessable_content)
      frame = response.parsed_body.at_css("turbo-frame#purchase_editor")
      expect(frame.at_css("[role='alert']").text).to include("Please correct")
      expect(frame.at_css("input[name='store_policy[store_name]']")["value"]).to eq("New Store")
      expect(frame.at_css("form")["data-modal-save"]).to eq("true")
    end

    it "saves a policy from the dialog and returns to the policy list" do
      expect do
        post store_policies_path, headers: { "Turbo-Frame" => "purchase_editor" },
          params: { store_policy: { store_name: "New Store", window_days: 30 } }
      end.to change(user.store_policies, :count).by(1)
      expect(response).to redirect_to(store_policies_path)
      follow_redirect!
      expect(response.body).to include("New Store", "Store return policy created.")
    end

    it "serves standalone and framed policy editors without duplicate frame IDs" do
      [ {}, { "Turbo-Frame" => "purchase_editor" } ].each do |headers|
        get edit_store_policy_path(policy), headers: headers
        expect(response).to have_http_status(:ok)
        html = response.parsed_body
        expect(html.css("turbo-frame#purchase_editor").size).to eq(1)
        frame = html.at_css("turbo-frame#purchase_editor")
        expect(frame["target"]).to eq(headers.empty? ? "_top" : nil)
        expect(frame.at_css("form[action='#{store_policy_path(policy)}']")["data-modal-save"]).to eq("true")
        expect(frame.at_css("a[data-modal-dismiss][href='#{store_policies_path}']")).to be_present
      end
    end

    it "keeps invalid policy edits and entered values in the dialog frame" do
      original = policy.attributes
      patch store_policy_path(policy), headers: { "Turbo-Frame" => "purchase_editor" },
        params: { store_policy: { store_name: "Still editing", window_days: 0 } }
      expect(response).to have_http_status(:unprocessable_content)
      frame = response.parsed_body.at_css("turbo-frame#purchase_editor")
      expect(frame.at_css("[role='alert']").text).to include("Please correct")
      expect(frame.at_css("input[name='store_policy[store_name]']")["value"]).to eq("Still editing")
      expect(frame.at_css("input[name='store_policy[window_days]']")["value"]).to eq("0")
      expect(policy.reload.attributes).to eq(original)
    end

    it "saves framed policy edits and returns the updated policy list" do
      patch store_policy_path(policy), headers: { "Turbo-Frame" => "purchase_editor" },
        params: { store_policy: { store_name: "Updated Store", window_days: 45 } }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(store_policies_path)
      follow_redirect!
      expect(response.body).to include("Updated Store", "45 days", "Store policy updated.")
      expect(policy.reload.window_days).to eq(45)
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

    it "rejects a duplicate name and window and preserves entered values after validation failure" do
      user.store_policies.create!(store_name: "Other Store", window_days: 14)
      patch store_policy_path(policy), params: { store_policy: { store_name: "other store", window_days: 14 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Store name already has a policy with that return window")
      html = response.parsed_body
      expect(html.at_css("input[name='store_policy[store_name]']")["value"]).to eq("other store")
      expect(html.at_css("input[name='store_policy[window_days]']")["value"]).to eq("14")
      expect(policy.reload.store_name).to eq("Campus Store")
    end

    it "shows a useful creation error when another request wins the uniqueness race" do
      policy
      # A racing request can insert after validation succeeds. Keep the other validations enabled.
      validator = StorePolicy.validators_on(:store_name).find { |item| item.kind == :uniqueness }
      allow(validator).to receive(:validate_each)
      expect do
        post store_policies_path, params: { store_policy: { store_name: "CAMPUS STORE", window_days: 30 } }
      end.not_to change(StorePolicy, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already has a policy with that return window")
      expect(response.parsed_body.at_css("input[name='store_policy[store_name]']")["value"]).to eq("CAMPUS STORE")
    end

    it "preserves the saved policy and reports a database uniqueness race during editing" do
      policy
      editing = user.store_policies.create!(store_name: "Book Shop", window_days: 14)
      validator = StorePolicy.validators_on(:store_name).find { |item| item.kind == :uniqueness }
      allow(validator).to receive(:validate_each)
      patch store_policy_path(editing), params: { store_policy: { store_name: "CAMPUS STORE", window_days: 30 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already has a policy with that return window")
      expect(editing.reload).to have_attributes(store_name: "Book Shop", window_days: 14)
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
      hint = response.parsed_body.at_css(".rc-policy-delete-hint")
      expect(hint["title"]).to be_nil
      expect(hint["tabindex"]).to eq("0")
      tooltip = hint.at_css("[role='tooltip']")
      expect(tooltip.text).to eq("In use by purchases; cannot be deleted.")
      expect(tooltip.key?("hidden")).to be(true)
      expect(hint["aria-describedby"]).to eq(tooltip["id"])
      expect(hint["data-action"]).to include("mouseenter->rc-tooltip#show", "focusin->rc-tooltip#show", "keydown.esc->rc-tooltip#hide")
      expect(response.parsed_body.at_css(".rc-policy-actions button[disabled]").text).to eq("Delete")
      expect(response.parsed_body.css("main form[action='#{store_policy_path(policy)}']")).to be_empty
    end
  end
end
