require "rails_helper"

RSpec.describe "Editing sample purchase templates", type: :request do
  let(:user) { User.create!(email_address: "sample-editor@example.com", password: "Password1!") }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  [ "/dashboard", "/history" ].each do |path|
    it "opens a prefilled sample from #{path} without saving on GET" do
      expect do
        get path
        card = response.parsed_body.at_css(".purchase-card")
        name = card.at_css("h2").text
        get card.at_css(".rc-card-actions a")["href"]
        expect(response).to have_http_status(:ok)
        html = response.parsed_body
        expect(html.at_css("h1").text).to eq("Edit Sample Purchase")
        expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq(name)
        expect(html.at_css("input[name='purchase[price]']")["value"].to_d).to be_positive
        expect(html.at_css("[role='note']").text).to include("demo template", "save")
        expect(html.css("form[action^='/purchases/']")).to be_empty
      end.not_to change { [ Purchase.count, StorePolicy.count ] }
    end
  end

  it "keeps the selected sample through policy validation and creation, then saves an owned purchase" do
    get new_purchase_path(sample: "Wireless Headphones")
    get response.parsed_body.at_css("a[href^='/store_policies/new']")["href"]
    sample = response.parsed_body.at_css("input[name='sample']")["value"]
    post store_policies_path, params: { origin: "purchase", sample: sample, store_policy: { store_name: "", window_days: 14 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("input[name='sample']")["value"]).to eq(sample)

    post store_policies_path, params: { origin: "purchase", sample: sample, store_policy: { store_name: "My Store", window_days: 14 } }
    follow_redirect!
    html = response.parsed_body
    expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Wireless Headphones")
    expect(html.at_css("select[name='purchase[store_policy_id]'] option[selected]")["value"]).to eq(user.store_policies.sole.id.to_s)
    fields = %w[item_name price purchase_date].to_h do |field|
      [ field, html.at_css("input[name='purchase[#{field}]']")["value"] ]
    end
    fields["item_name"] = "My Edited Headphones"
    fields["store_policy_id"] = user.store_policies.sole.id
    expect { post purchases_path, params: { purchase: fields } }.to change(user.purchases, :count).by(1)
    expect(user.purchases.sole.return_by).to eq(Date.parse(fields["purchase_date"]) + 14)
    follow_redirect!
    get history_path
    expect(response.parsed_body.at_css(".purchase-card[data-sample='false'] h2").text).to eq("My Edited Headphones")
    expect(response.parsed_body.css(".rc-sample-notice")).to be_empty
  end

  it "ignores unknown samples and never selects another user's policy" do
    other = User.create!(email_address: "private-sample@example.com", password: "Password1!")
    policy = other.store_policies.create!(store_name: "Campus Store", window_days: 30)
    get new_purchase_path(sample: "Wireless Headphones", store_policy_id: policy.id)
    expect(response.parsed_body.css("select[name='purchase[store_policy_id]']")).to be_empty
    expect(response.parsed_body.at_css("input[type='submit']")["disabled"]).to be_present

    get new_purchase_path(sample: "<script>arbitrary</script>", item_name: "Injected")
    expect(response.parsed_body.at_css("input[name='purchase[item_name]']")["value"]).to be_nil
    expect(response.parsed_body.css("[role='note']")).to be_empty
    expect(user.purchases).to be_empty
  end

  it "keeps the sample editing title and entered values after validation fails" do
    policy = user.store_policies.create!(store_name: "My Store", window_days: 30)
    post purchases_path, params: { sample: "Wireless Headphones", purchase: {
      item_name: "Changed sample", price: -1, purchase_date: Date.current, store_policy_id: policy.id
    } }
    expect(response).to have_http_status(:unprocessable_content)
    html = response.parsed_body
    expect(html.at_css("h1").text).to eq("Edit Sample Purchase")
    expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Changed sample")
    expect(html.at_css("input[name='sample']")["value"]).to eq("Wireless Headphones")
    expect(user.purchases).to be_empty
  end
end
