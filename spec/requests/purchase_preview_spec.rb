require "rails_helper"

RSpec.describe "Integrated purchase interactions", type: :request do
  let(:user) { User.create!(email_address: "preview@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Own Store", window_days: 30) }

  before { post session_path, params: { email_address: user.email_address, password: "Password1!" } }

  it "uses the real edit link for escaped persisted cards and hides the preview dialogs" do
    purchase = user.purchases.create!(item_name: "<script>example</script>", price: 15,
      purchase_date: Date.current, store_policy: policy, status: "active")
    get dashboard_path
    html = response.parsed_body
    card = html.at_css(".purchase-card")
    expect(card.css("script")).to be_empty
    expect(card.text).to include(purchase.item_name)
    expect(html.at_css("main a[href='#{new_purchase_path}']")).to be_present
    expect(card.at_css("a[href='#{edit_purchase_path(purchase)}']")).to be_present
    expect(card.at_css("a[href='#{confirm_delete_purchase_path(purchase)}']")).to be_nil
    expect(card.at_css("form[action='#{purchase_path(purchase)}'] input[name='_method']")["value"]).to eq("patch")
    expect(card.at_css(".rc-card-edit").text.strip).to eq("Edit")
    actions = card.at_css(".rc-card-actions")
    expect(actions.xpath("./a")).to be_empty
    expect(actions.css("details, .rc-status-mini-form")).to be_empty
    expect(html.css("dialog[open], [data-action^='rc-purchase-preview#']")).to be_empty
  end

  it "offers editable demo templates without writing on page views" do
    expect { get dashboard_path }.not_to change(Purchase, :count)
    html = response.parsed_body
    expect(html.at_css("main a[href='#{new_purchase_path}']")).to be_present
    expect(html.css(".purchase-card").size).to eq(7)
    expect(html.css(".purchase-card .rc-card-edit").size).to eq(7)
    expect(html.css(".purchase-card .rc-card-actions form, .purchase-card .rc-card-actions details, dialog[open]")).to be_empty
  end
end
