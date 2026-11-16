require "rails_helper"

RSpec.describe "Purchase editor dialog", type: :request do
  let(:user) { User.create!(email_address: "modal@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Modal Store", window_days: 30) }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  it "targets the shared dialog from Add Purchase and sample Edit" do
    get dashboard_path
    html = response.parsed_body
    expect(html.at_css("main a[href='#{new_purchase_path}']")["data-turbo-frame"]).to eq("purchase_editor")
    expect(html.css(".purchase-card .rc-card-actions a").map { |link| link["data-turbo-frame"] }.uniq).to eq([ "purchase_editor" ])
    expect(html.css("dialog.rc-purchase-modal turbo-frame#purchase_editor").size).to eq(1)
    expect(html.css("dialog[open]")).to be_empty
  end

  it "serves standalone editors and matching frame content with no duplicate frame IDs" do
    [ {}, { "Turbo-Frame" => "purchase_editor" } ].each do |headers|
      get new_purchase_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("turbo-frame#purchase_editor").size).to eq(1)
      expect(response.parsed_body.at_css("turbo-frame#purchase_editor")["target"]).to eq(headers.empty? ? "_top" : nil)
      expect(response.parsed_body.at_css("turbo-frame#purchase_editor form[action='#{purchases_path}']")).to be_present
    end
  end

  it "keeps rejected edits and their values in the frame without saving" do
    purchase = user.purchases.create!(item_name: "Notebook", price: 20, purchase_date: Date.current, store_policy: policy)
    original = purchase.attributes
    patch purchase_path(purchase), headers: { "Turbo-Frame" => "purchase_editor" },
      params: { purchase: { item_name: "Still editing", price: -1 } }
    expect(response).to have_http_status(:unprocessable_content)
    frame = response.parsed_body.at_css("turbo-frame#purchase_editor")
    expect(frame.at_css("[role='alert']").text).to include("Price must be greater than 0")
    expect(frame.at_css("input[name='purchase[item_name]']")["value"]).to eq("Still editing")
    expect(purchase.reload.attributes).to eq(original)
  end

  it "keeps policy setup in the same frame" do
    get new_store_policy_path(sample: "Wireless Headphones"), headers: { "Turbo-Frame" => "purchase_editor" }
    expect(response.parsed_body.at_css("turbo-frame#purchase_editor form[action='#{store_policies_path}']")).to be_present
    expect(response.parsed_body.at_css("turbo-frame#purchase_editor")["target"]).to be_nil
    get new_store_policy_path
    expect(response.parsed_body.at_css("turbo-frame#purchase_editor")["target"]).to eq("_top")
  end

  it "saves a framed purchase and returns the Dashboard destination with its flash" do
    expect do
      post purchases_path, headers: { "Turbo-Frame" => "purchase_editor" },
        params: { purchase: { item_name: "Modal purchase", price: 20, purchase_date: Date.current, store_name: policy.store_name } }
    end.to change(user.purchases, :count).by(1)
    expect(response).to redirect_to(dashboard_path)
    expect(URI.parse(response.location).path).to eq(dashboard_path)
    get response.location
    expect(response.parsed_body.at_css("[role='status']").text).to eq("Purchase added.")
  end

  it "returns the History destination after a framed status edit" do
    purchase = user.purchases.create!(item_name: "Notebook", price: 20, purchase_date: Date.current, store_policy: policy)
    patch purchase_path(purchase), headers: { "Turbo-Frame" => "purchase_editor" }, params: { purchase: { status: "keeping" } }
    expect(response).to redirect_to(history_path)
    expect(URI.parse(response.location).path).to eq(history_path)
    expect(purchase.reload.status).to eq("keeping")
    get response.location
    expect(response.parsed_body.at_css("[role='status']").text).to eq("Purchase updated.")
  end
end
