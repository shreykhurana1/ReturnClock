require "rails_helper"

# The purchase form explains what it would save as the shopper types; the controller itself is covered in
# test/javascript. These specs cover what the server hands it.
RSpec.describe "Purchase form live feedback", type: :request do
  let(:user) { User.create!(email_address: "student@example.com", password: "Password1!") }
  let!(:policy) { user.store_policies.create!(store_name: "Campus Store", window_days: 30) }
  let(:form) { Nokogiri::HTML(response.body).at_css("form.rc-purchase-form") }

  around do |example|
    travel_to(Time.utc(2026, 11, 8, 12)) { example.run }
  end

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  it "describes the new purchase form to the feedback controller" do
    get new_purchase_path

    expect(form["data-controller"]).to eq("rc-purchase-feedback")
    expect(form["data-rc-purchase-feedback-today-value"]).to eq("2026-11-08")
    expect(form.attributes.keys).not_to include("data-rc-purchase-feedback-saved-return-by-value")
  end

  it "gives each store policy option its return window" do
    get new_purchase_path

    option = form.at_css("select[name='purchase[store_policy_id]'] option[value='#{policy.id}']")
    expect(option["data-window-days"]).to eq("30")
    expect(option.text).to eq(policy.label)
  end

  it "shows $0.00 as the placeholder and does not require a price" do
    get new_purchase_path

    price = form.at_css("input[name='purchase[price]']")
    expect(price["placeholder"]).to eq("0.00")
    expect(price["required"]).to be_nil
    expect(price["min"]).to eq("0")
  end

  it "renders a summary of what will be saved without saving anything" do
    get new_purchase_path

    summary = form.at_css(".rc-save-summary")
    expect(summary.text).to include("What will be saved", "$0.00", "Choose a store policy", "Nothing is saved until you choose Add Purchase.")
    expect(form.css("[data-rc-purchase-feedback-target='error']").map { |error| error["data-field"] })
      .to eq(%w[item_name price purchase_date store_policy_id])
    expect(Purchase.count).to eq(0)
  end

  it "passes an existing purchase's stored date, policy and deadline so an untouched deadline is kept" do
    purchase = user.purchases.create!(store_policy: policy, item_name: "Coat", price: 20, purchase_date: Date.new(2026, 11, 1))
    policy.update!(window_days: 60)

    get edit_purchase_path(purchase)

    expect(form["data-rc-purchase-feedback-saved-date-value"]).to eq("2026-11-01")
    expect(form["data-rc-purchase-feedback-saved-policy-value"]).to eq(policy.id.to_s)
    expect(form["data-rc-purchase-feedback-saved-return-by-value"]).to eq("2026-12-01")
    expect(form.at_css(".rc-save-summary").text).to include("$20.00", "December 01, 2026").or include("December 1, 2026")
    expect(form.at_css(".rc-save-summary").text).to include("Nothing is saved until you choose Save Purchase.")
  end

  it "counts today in the signed-in user's time zone" do
    user.update!(time_zone: "Auckland")
    travel 8.hours # 20:00 UTC is already the next morning in Auckland
    get new_purchase_path
    expect(form["data-rc-purchase-feedback-today-value"]).to eq("2026-11-09")
  end

  it "no longer saves edits in the background" do
    purchase = user.purchases.create!(store_policy: policy, item_name: "Coat", price: 20, purchase_date: Date.new(2026, 11, 1))
    get edit_purchase_path(purchase)

    expect(form["data-controller"]).not_to include("autosave")
    patch purchase_path(purchase), params: { autosave: "1", purchase: { item_name: "Changed" } }
    expect(response).to redirect_to(dashboard_path)
    expect(purchase.reload.item_name).to eq("Changed")
  end
end
