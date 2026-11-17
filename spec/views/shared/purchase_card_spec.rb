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

  { "active" => "success", "keeping" => "secondary", "returning" => "orange",
    "shipped_back" => "purple", "refund_pending" => "amber", "refunded" => "teal" }.each do |status, color|
    it "uses #{color} for #{status}" do
      sample.status = status
      html = sample_html(previews_enabled: false)
      expect(html.at_css(".rc-card-top .rc-chip-#{color}")).to be_present
      expect(html.at_css(".rc-card-top > :first-child")["class"]).to include("rc-chip")
      expect(html.at_css(".rc-card-top .rc-chip").text).to eq(I18n.t("ui.#{status}"))
      expect(html.css(".rc-contract-details dt").map(&:text)).not_to include("Status")
      expect(html.css(".rc-contract-details dt").map(&:text)).not_to include("Price")
      expect(html.at_css(".rc-price").text).to eq("$25.00")
      expect(html.css(".rc-card-bottom > .rc-muted")).to be_empty
      expect(html.css(".rc-days")).to be_empty
      expect(html.css(".rc-contract-details dt").map(&:text).include?("Days remaining")).to eq(!%w[keeping refunded].include?(status))
      expect(html.css(".rc-card-bottom > .rc-days, .rc-product-symbol")).to be_empty
    end
  end

  { -1 => "danger", 0 => "success", 2 => "success", 7 => "success", 8 => "success" }.each do |days, color|
    it "uses #{color} for an active purchase with #{days} days left" do
      sample.return_by = Date.current + days
      html = sample_html(previews_enabled: false)
      expect(html.at_css(".rc-card-top .rc-chip-#{color}")).to be_present
      expect(html.css(".rc-card-bottom > .rc-muted")).to be_empty
      expect(html.css(".rc-days")).to be_empty
      expect(html.css(".rc-contract-details dd").map(&:text)).to include(days.to_s) if days >= 0
      expect(html.css(".rc-card-bottom > .rc-days")).to be_empty
      expect(html.css(".rc-days-urgent, .rc-chip-warning")).to be_empty
    end
  end

  it "keeps the safe demo preview buttons before the backend CRUD routes exist" do
    html = sample_html(previews_enabled: true)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.css(".rc-card-actions button[data-action^='rc-purchase-preview#']").size).to eq(3)
    expect(html.css(".rc-card-actions form")).to be_empty
    expect(html.css(".rc-card-actions > .rc-btn").map(&:text)).to eq([ "Edit", "Update status", "Delete" ])
    expect(html.css(".rc-card-more")).to be_empty
  end

  it "links demo Edit to a new purchase template without exposing mutation actions" do
    html = sample_html(previews_enabled: false)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.at_css(".rc-product-name").text).to eq("Demo Notebook")
    link = html.at_css(".rc-card-actions a")
    expect(link.text).to eq("Edit")
    expect(link["href"]).to eq(new_purchase_path(sample: sample.item_name))
    expect(html.css(".rc-card-actions form, .rc-card-actions details, [data-action^='rc-purchase-preview#']")).to be_empty
  end
end
