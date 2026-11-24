require "rails_helper"

RSpec.describe "Accessible purchase and policy validation", type: :request do
  let(:user) { User.create!(email_address: "validation@example.com", password: "Password1!") }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  def expect_field_error(html, name, message)
    field = html.at_css("[name='#{name}']")
    expect(field["aria-invalid"]).to eq("true")
    ids = field["aria-describedby"].split
    expect(ids).not_to be_empty
    ids.each { |id| expect(html.css("##{id}").size).to eq(1) }
    expect(ids.map { |id| html.at_css("##{id}").text }.join(" ")).to include(message)
  end

  it "associates every invalid purchase field with its own errors, including the policy association" do
    user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    expect do
      post purchases_path, params: { purchase: { item_name: "", price: -5, purchase_date: "", store_policy_id: "", status: "unknown" } }
    end.not_to change(Purchase, :count)
    expect(response).to have_http_status(:unprocessable_content)
    html = response.parsed_body
    { "item_name" => "Item name can't be blank", "price" => "Price must be greater than 0",
      "purchase_date" => "Purchase date can't be blank", "store_policy_id" => "Store policy must exist",
      "status" => "Status is not included" }.each do |field, error|
      expect_field_error(html, "purchase[#{field}]", error)
    end
    expect(html.at_css("input[name='purchase[price]']")["value"]).to eq("-5")
    expect(html.at_css("[role='alert']")["tabindex"]).to eq("-1")
    expect(html.at_css("[role='alert']")["data-controller"]).to eq("rc-error-focus")
    expect(html.at_css("select[name='purchase[status]']")["aria-describedby"]).to include("purchase-status-hint")
  end

  it "places policy validation beside the corresponding fields and retains the submitted values" do
    post store_policies_path, params: { store_policy: { store_name: "", window_days: 0 } }
    expect(response).to have_http_status(:unprocessable_content)
    html = response.parsed_body
    expect_field_error(html, "store_policy[store_name]", "Store name can't be blank")
    expect_field_error(html, "store_policy[window_days]", "Window days must be greater than 0")
    expect(html.at_css("input[name='store_policy[window_days]']")["value"]).to eq("0")
    expect(html.at_css("[role='alert']")["data-controller"]).to eq("rc-error-focus")
    expect(StorePolicy.count).to eq(0)
  end

  it "does not focus an error summary or mark valid fresh fields as invalid" do
    [ new_purchase_path, new_store_policy_path ].each do |path|
      get path
      expect(response.parsed_body.css("[data-controller='rc-error-focus'], [aria-invalid='true']")).to be_empty
    end
  end
end
