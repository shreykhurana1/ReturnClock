require "rails_helper"

RSpec.describe "Purchase and store policy creation", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let(:other_user) { User.create!(email_address: "other@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:other_policy) { other_user.store_policies.create!(store_name: "Private Store", window_days: 14) }
  let(:attributes) do
    { item_name: "Textbook", price: "49.99", purchase_date: "2026-11-08", store_name: policy.store_name }
  end

  around do |example|
    travel_to(Time.zone.local(2026, 11, 8, 12)) { example.run }
  end

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "Password1!" }
  end

  [ "/purchases/new", "/store_policies/new" ].each do |path|
    it "requires authentication to open #{path}" do
      get path
      expect(response).to redirect_to(new_session_path)
    end
  end

  [ "/purchases", "/store_policies" ].each do |path|
    it "requires authentication to submit #{path}" do
      expect { post path, params: {} }.not_to change(Purchase, :count)
      expect(response).to redirect_to(new_session_path)
      expect(StorePolicy.count).to eq(0)
    end
  end

  context "when signed in" do
    before { sign_in }

    it "lets a first-time user add a purchase with a typed store, then save that store from the prompt" do
      get new_purchase_path
      expect(response.body).not_to include("Create a store return policy before adding your first purchase.")
      expect(response.parsed_body.at_css("input[type='submit']")["disabled"]).to be_nil
      expect(response.parsed_body.at_css("input[name='purchase[purchase_date]']")["value"]).to eq("2026-11-08")

      expect do
        post purchases_path, params: { purchase: { item_name: "Textbook", price: "49.99",
          purchase_date: "2026-11-08", store_name: "Campus Store", return_window_days: "30" } }
      end.to change(user.purchases, :count).by(1)
      expect(response).to redirect_to(dashboard_path)
      expect(user.purchases.sole.return_by).to eq(Date.new(2026, 12, 8))
      follow_redirect!
      card = response.parsed_body.at_css(".purchase-card")
      expect(card.text).to include("Textbook", "Campus Store", "$49.99", "Active")
      expect(card.at_css("time")["datetime"]).to eq("2026-12-08")
      expect(response.body).to include(%(Save store "Campus Store" with a 30 day return window?))

      post store_policies_path, params: { origin: "banner", store_policy: { store_name: "Campus Store", window_days: 30 } },
        headers: { "HTTP_REFERER" => dashboard_url }
      expect(response).to redirect_to(dashboard_url)
      expect(user.purchases.sole.store_policy).to eq(user.store_policies.sole)
    end

    it "assigns a policy to Current.user even when another owner is submitted" do
      other_user
      expect do
        post store_policies_path, params: { store_policy: { store_name: "Campus Store", window_days: 30, user_id: other_user.id } }
      end.to change(user.store_policies, :count).by(1)
      expect(other_user.store_policies).to be_empty
      expect(user.store_policies.sole.window_days).to eq(30)
    end

    [ { store_name: "", window_days: 30 }, { store_name: "Campus Store", window_days: 0 },
      { store_name: "Campus Store", window_days: 1.5 } ].each do |invalid_attributes|
      it "renders useful policy errors for #{invalid_attributes.inspect}" do
        expect do
          post store_policies_path, params: { store_policy: invalid_attributes }
        end.not_to change(StorePolicy, :count)
        expect(response).to have_http_status(:unprocessable_content)
        error = invalid_attributes[:store_name].empty? ? "Store name can't be blank" : "Window days must"
        expect(response.parsed_body.at_css("[role='alert']").text).to include("Please correct", error)
        expect(response.parsed_body.at_css("form[action='#{store_policies_path}']")).to be_present
      end
    end

    it "rejects a duplicate store policy for the same user and retains the entered fields" do
      policy
      expect do
        post store_policies_path, params: { store_policy: { store_name: policy.store_name, window_days: 14 } }
      end.not_to change(StorePolicy, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Store name has already been taken")
      expect(response.parsed_body.at_css("input[name='store_policy[store_name]']")["value"]).to eq(policy.store_name)
      expect(response.parsed_body.at_css("input[name='store_policy[window_days]']")["value"]).to eq("14")
    end

    it "allows a user to create a store policy with the same name as another user's policy" do
      other_policy
      expect do
        post store_policies_path, params: { store_policy: { store_name: other_policy.store_name, window_days: 30 } }
      end.to change(user.store_policies, :count).by(1)
      expect(response).to redirect_to(store_policies_path)
    end

    it "never reveals another user's stores on the new purchase form" do
      policy
      get new_purchase_path, params: { store_policy_id: other_policy.id, user_id: other_user.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_policy.store_name, other_user.email_address)
      expect(response.parsed_body.css("input[name$='[user_id]'], [name='purchase[store_policy_id]']")).to be_empty
    end

    it "does not fill in a window from another user's saved store" do
      other_policy
      params = { item_name: "Bag", purchase_date: "2026-11-08", store_name: other_policy.store_name }
      expect { post purchases_path, params: { purchase: params } }.not_to change(Purchase, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Add a return-by date, or a purchase date and return window")
    end

    it "ignores a submitted owner while accepting an allowed status" do
      other_user
      expect do
        post purchases_path, params: { purchase: attributes.merge(user_id: other_user.id, status: "refunded") }
      end.to change(user.purchases, :count).by(1)
      purchase = user.purchases.sole
      expect(purchase.store_policy).to eq(policy)
      expect(purchase.return_by).to eq(Date.new(2026, 12, 8))
      expect(purchase.status).to eq("refunded")
      expect(response).to redirect_to(history_path)
      expect(other_user.purchases).to be_empty
    end

    [ { item_name: "" }, { price: 0 }, { purchase_date: "" }, { return_window_days: -1 }, { status: "unknown" } ].each do |invalid_attributes|
      it "rejects invalid purchase fields #{invalid_attributes.inspect} without saving" do
        params = attributes.merge(invalid_attributes)
        expect { post purchases_path, params: { purchase: params } }.not_to change(Purchase, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("[role='alert']").text).to include("Please correct")
        expect(response.parsed_body.at_css("form[action='#{purchases_path}']")).to be_present
      end
    end

    it "retains purchase values and the owned selection when validation fails, without exposing other policies" do
      other_policy
      post purchases_path, params: { purchase: attributes.merge(price: "-1") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Price must be greater than 0")
      expect(response.body).not_to include(other_policy.store_name)
      expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to eq("Textbook")
      expect(response.parsed_body.at_css("input[name='purchase[price]']")["value"]).to eq("-1")
      expect(response.parsed_body.at_css("input[name='purchase[store_name]']")["value"]).to eq(policy.store_name)
    end

    [ :other, -1 ].each do |forged|
      it "ignores a submitted store_policy_id (#{forged}) and links the purchase by its own store" do
        forged_id = forged == :other ? other_policy.id : forged
        expect { post purchases_path, params: { purchase: attributes.merge(store_policy_id: forged_id) } }
          .to change(user.purchases, :count).by(1)
        expect(user.purchases.sole.store_policy).to eq(policy)
        expect(other_user.store_policies.flat_map(&:purchases)).to be_empty
      end
    end

    it "preserves History classification for a newly entered purchase whose deadline has passed" do
      post purchases_path, params: { purchase: attributes.merge(purchase_date: "2026-09-01") }
      expect(response).to redirect_to(history_path)
      follow_redirect!
      expect(response.parsed_body.at_css(".purchase-card h2").text).to eq("Textbook")
      get dashboard_path
      expect(response.parsed_body.css(".purchase-card")).to be_empty
    end
  end
end
