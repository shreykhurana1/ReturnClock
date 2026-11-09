require "rails_helper"

RSpec.describe "Purchase management", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:other_user) { User.create!(email_address: "other@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:purchase) do
    user.purchases.create!(store_policy: policy, item_name: "Textbook", price: "49.99", purchase_date: Date.current)
  end
  let(:other_policy) { other_user.store_policies.create!(store_name: "Private Store", window_days: 14) }
  let(:other_purchase) do
    other_user.purchases.create!(store_policy: other_policy, item_name: "Private Purchase", price: 10, purchase_date: Date.current)
  end

  around do |example|
    travel_to(Time.zone.local(2026, 11, 8, 12)) { example.run }
  end

  def card_names
    response.parsed_body.css(".purchase-card[data-sample='false'] h2").map(&:text)
  end

  { get: %w[edit confirm_delete], patch: [ nil ], delete: [ nil ] }.each do |method, actions|
    actions.each do |action|
      it "requires authentication for #{method} purchase #{action}" do
        path = action ? "/purchases/#{purchase.id}/#{action}" : purchase_path(purchase)
        original = purchase.attributes
        public_send(method, path, params: { purchase: { item_name: "Changed" } })
        expect(response).to redirect_to(new_session_path)
        expect(purchase.reload.attributes).to eq(original)
      end
    end
  end

  context "when signed in" do
    before do
      post session_path, params: { email_address: user.email_address, password: "Password1!" }
    end

    { get: %w[edit confirm_delete], patch: [ nil ], delete: [ nil ] }.each do |method, actions|
      actions.each do |action|
        it "rejects #{method} #{action} for another user's purchase" do
          path = action ? "/purchases/#{other_purchase.id}/#{action}" : purchase_path(other_purchase)
          original = other_purchase.attributes
          # Public 404 pages omit the test source excerpts shown by Rails' debug page.
          allow(Rails.application).to receive(:env_config).and_return(
            Rails.application.env_config.merge("action_dispatch.show_detailed_exceptions" => false))
          public_send(method, path, params: { user_id: other_user.id, purchase: { item_name: "Changed", user_id: user.id } })
          expect(response).to have_http_status(:not_found)
          expect(response.body).not_to include("Private Purchase", "Private Store")
          expect(other_purchase.reload.attributes).to eq(original)
        end
      end
    end

    it "shows editable values, all six statuses, and only owned policies" do
      other_policy
      get edit_purchase_path(purchase)
      expect(response).to have_http_status(:ok)
      html = response.parsed_body
      expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Textbook")
      expect(html.at_css("input[name='purchase[purchase_date]']")["value"]).to eq("2026-11-08")
      expect(html.css("select[name='purchase[status]'] option").map { |option| option["value"] }).to eq(Purchase::STATUSES)
      expect(html.css("select[name='purchase[store_policy_id]'] option").map(&:text)).to include(policy.store_name)
      expect(response.body).not_to include(other_policy.store_name)
      expect(html.css("input[name='purchase[user_id]'], input[name='purchase[return_by]']")).to be_empty
    end

    it "updates item and price while preserving the deadline after a policy window edit" do
      deadline = purchase.return_by
      policy.update!(window_days: 60)
      patch purchase_path(purchase), params: { purchase: { item_name: "Updated Textbook", price: "29.99" } }
      expect(response).to redirect_to(dashboard_path)
      expect(purchase.reload.item_name).to eq("Updated Textbook")
      expect(purchase.price).to eq(BigDecimal("29.99"))
      expect(purchase.return_by).to eq(deadline)
    end

    it "recalculates from a changed date using the policy's current saved window" do
      purchase
      policy.update!(window_days: 60)
      patch purchase_path(purchase), params: { purchase: { purchase_date: "2026-11-01" } }
      expect(response).to redirect_to(dashboard_path)
      expect(purchase.reload.return_by).to eq(Date.new(2026, 12, 31))
    end

    it "recalculates when an owned replacement policy is selected" do
      replacement = user.store_policies.create!(store_name: "Other Store", window_days: 14)
      patch purchase_path(purchase), params: { purchase: { store_policy_id: replacement.id } }
      expect(response).to redirect_to(dashboard_path)
      expect(purchase.reload.store_policy).to eq(replacement)
      expect(purchase.return_by).to eq(Date.new(2026, 11, 22))
    end

    it "ignores ownership and deadline fields while applying allowed edits" do
      deadline = purchase.return_by
      patch purchase_path(purchase), params: { purchase: { item_name: "Updated", user_id: other_user.id, return_by: "2099-01-01" } }
      expect(response).to redirect_to(dashboard_path)
      expect(purchase.reload.user).to eq(user)
      expect(purchase.return_by).to eq(deadline)
      expect(purchase.item_name).to eq("Updated")
    end

    it "rejects another user's policy without saving any part of the edit" do
      original = purchase.attributes
      patch purchase_path(purchase), params: { purchase: { item_name: "Should not persist", store_policy_id: other_policy.id } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Store policy must exist")
      expect(response.body).not_to include(other_policy.store_name)
      expect(purchase.reload.attributes).to eq(original)
    end

    [ { item_name: "" }, { price: 0 }, { purchase_date: "" }, { store_policy_id: -1 }, { status: "expired" } ].each do |invalid|
      it "renders edit errors without changing the purchase for #{invalid.inspect}" do
        original = purchase.attributes
        patch purchase_path(purchase), params: { purchase: invalid }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("[role='alert']").text).to include("Please correct")
        expect(response.parsed_body.at_css("form[action='#{purchase_path(purchase)}']")).to be_present
        expect(purchase.reload.attributes).to eq(original)
      end
    end

    it "retains non-sensitive values after an invalid edit" do
      patch purchase_path(purchase), params: { purchase: { item_name: "Updated Textbook", price: "-5", status: "returning" } }
      expect(response).to have_http_status(:unprocessable_content)
      html = response.parsed_body
      expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Updated Textbook")
      expect(html.at_css("input[name='purchase[price]']")["value"]).to eq("-5")
      expect(html.at_css("select[name='purchase[status]'] option[selected]")["value"]).to eq("returning")
      expect(html.at_css("select[name='purchase[store_policy_id]'] option[selected]")["value"]).to eq(policy.id.to_s)
    end

    Purchase::STATUSES.each do |status|
      it "accepts #{status} and routes it to the correct page" do
        deadline = purchase.return_by
        patch purchase_path(purchase), params: { purchase: { status: status } }
        destination = %w[keeping refunded].include?(status) ? history_path : dashboard_path
        expect(response).to redirect_to(destination)
        expect(purchase.reload.status).to eq(status)
        expect(purchase.return_by).to eq(deadline)
        follow_redirect!
        expect(card_names).to include("Textbook")
        expect(response.body).to include("Purchase updated.")
        status_select = response.parsed_body.at_css(".rc-status-mini-form select")
        expect(status_select.css("option").map { |option| option["value"] })
          .to contain_exactly(*(%w[active keeping refunded] + [ status ]).uniq)
        expect(status_select.at_css("option[selected]")["value"]).to eq(status)
        get(destination == dashboard_path ? history_path : dashboard_path)
        expect(card_names).not_to include("Textbook")
      end
    end

    %w[returning shipped_back refund_pending].each do |status|
      it "moves an expired #{status} purchase from History to Dashboard" do
        purchase.update!(purchase_date: Date.current - 40)
        patch purchase_path(purchase), params: { purchase: { status: status } }
        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(card_names).to include("Textbook")
        get history_path
        expect(card_names).not_to include("Textbook")
      end
    end

    it "keeps expired active purchases in History after editing" do
      patch purchase_path(purchase), params: { purchase: { purchase_date: Date.current - 40, status: "active" } }
      expect(response).to redirect_to(history_path)
      follow_redirect!
      expect(card_names).to include("Textbook")
    end

    it "keeps the saved deadline on a status change after the policy window was edited" do
      deadline = purchase.return_by
      policy.update!(window_days: 90)
      patch purchase_path(purchase), params: { purchase: { status: "keeping" } }
      expect(purchase.reload.return_by).to eq(deadline)
    end

    it "provides edit and confirmation links on both Dashboard and History cards" do
      [ dashboard_path, history_path ].each do |path|
        purchase.update!(status: path == dashboard_path ? "active" : "keeping")
        get path
        card = response.parsed_body.at_css(".purchase-card")
        expect(card.at_css("a[href='#{edit_purchase_path(purchase)}']").text).to eq("Edit")
        expect(card.at_css("a[href='#{confirm_delete_purchase_path(purchase)}']").text).to eq("Delete")
      end
    end

    it "shows a separate confirmation with a cancel link without deleting on GET" do
      purchase
      expect { get confirm_delete_purchase_path(purchase) }.not_to change(Purchase, :count)
      expect(response).to have_http_status(:ok)
      html = response.parsed_body
      expect(html.at_css("main").text).to include("Textbook", "This cannot be undone.")
      expect(html.at_css("a[href='#{edit_purchase_path(purchase)}']").text).to eq("Cancel")
      expect(html.at_css("form[action='#{purchase_path(purchase)}'] input[name='_method']")["value"]).to eq("delete")
      expect { get purchase_path(purchase) }.not_to change(Purchase, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "deletes only the selected owned purchase and retains its policy" do
      purchase
      other_purchase
      expect { delete purchase_path(purchase) }.to change(user.purchases, :count).by(-1)
      expect(response).to redirect_to(dashboard_path)
      expect(Purchase.exists?(other_purchase.id)).to be(true)
      expect(StorePolicy.exists?(policy.id)).to be(true)
    end

    it "returns to History after deleting a completed purchase" do
      purchase.update!(status: "refunded")
      delete purchase_path(purchase)
      expect(response).to redirect_to(history_path)
      follow_redirect!
      expect(response.body).to include("Purchase deleted.")
      expect(card_names).to be_empty
      expect(response.parsed_body.at_css(".rc-sample-notice").text).to include("Demo preview")
    end
  end
end
