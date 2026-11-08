require "rails_helper"

RSpec.describe "shared/_purchase_card", type: :view do
  let(:sample) do
    Purchase.new(
      item_name: "Demo Notebook", price: "25.00", purchase_date: Date.current,
      return_by: Date.current + 30, status: "active",
      store_policy: StorePolicy.new(store_name: "Sample Store", window_days: 30)
    )
  end

  def sample_html(previews_enabled:)
    allow(view).to receive(:purchase_preview_enabled?).and_return(previews_enabled)
    render partial: "shared/purchase_card", locals: { purchase: sample }
    Nokogiri::HTML.fragment(rendered)
  end

  it "keeps the safe demo preview buttons before the backend CRUD routes exist" do
    html = sample_html(previews_enabled: true)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.css(".rc-card-actions button[data-action^='rc-purchase-preview#']").size).to eq(3)
    expect(html.css(".rc-card-actions form")).to be_empty
  end

  it "removes demo action buttons once real CRUD routes replace preview dialogs" do
    html = sample_html(previews_enabled: false)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.at_css(".rc-product-name").text).to eq("Demo Notebook")
    expect(html.css(".rc-card-actions, [data-action^='rc-purchase-preview#']")).to be_empty
  end
end
