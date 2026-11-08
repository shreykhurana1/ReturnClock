require "rails_helper"

RSpec.describe "Purchase interaction previews", type: :request do
  let(:user) { User.create!(email_address: "preview@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Own Store", window_days: 30) }

  before do
    # Once all CRUD routes exist, these legacy preview-dialog assertions no longer apply.
    routes_ready = %i[new_purchase_path edit_purchase_path purchase_path].all? do |route|
      Rails.application.routes.url_helpers.respond_to?(route)
    end
    skip "Preview dialogs are replaced by real purchase CRUD routes" if routes_ready

    post session_path, params: { email_address: user.email_address, password: "Password1!" }
  end

  it "offers add, edit, status and delete dialogs without adding write endpoints or records" do
    user.purchases.create!(item_name: "<script>example</script>", price: 15,
      purchase_date: Date.current, store_policy: policy, status: "active")
    expect { get dashboard_path }.not_to change(Purchase, :count)
    html = response.parsed_body
    card = html.at_css(".purchase-card")
    data = JSON.parse(card["data-purchase-preview"])
    expect(data.fetch("item_name")).to eq("<script>example</script>")
    expect(data.fetch("store_policy_id")).to eq(policy.id)
    expect(card.css("script")).to be_empty
    expect(html.at_css("main a[data-action='rc-purchase-preview#new']")["href"]).to eq(coming_soon_add_purchase_path)
    expect(card.at_css("button[data-action='rc-purchase-preview#edit']")).to be_present
    expect(card.at_css("button[data-action='rc-purchase-preview#status']")).to be_present
    expect(card.at_css("button[data-action='rc-purchase-preview#delete']")).to be_present
    expect(html.css("dialog").size).to eq(3)
    form = html.at_css("dialog[data-rc-purchase-preview-target='editor'] form")
    expect(form["action"]).to eq("#")
    expect(form["method"]).to eq("get")
    expect(form["data-action"]).to eq("submit->rc-purchase-preview#pending")
    expect(html.at_css("fieldset[data-rc-purchase-preview-target='fields']")["disabled"]).not_to be_nil
    expect(html.css("dialog form[action^='/purchases']")).to be_empty
    expect(html.css("#rc-preview-status option").map { |option| option["value"] }).to eq(%w[active keeping refunded])
    expect(html.at_css("dialog [data-preview-message]").text).to include("No purchase was added, changed or deleted")
  end

  it "uses English dialog text and only the current user's store policies" do
    other = User.create!(email_address: "other-preview@example.com", password: "Password1!")
    other.store_policies.create!(store_name: "Other Private Store", window_days: 60)
    policy
    get dashboard_path, params: { lang: "zh" }
    html = response.parsed_body
    expect(html.at_css("#rc-editor-title").text).to eq("Add Purchase")
    expect(html.at_css("dialog [data-preview-message]").text).to include("Waiting for backend integration", "has not been saved")
    select = html.at_css("dialog select[name='purchase[store_policy_id]']")
    expect(select.text).to include("Own Store")
    expect(select.text).not_to include("Other Private Store")
  end
end
