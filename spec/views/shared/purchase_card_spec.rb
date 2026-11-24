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

  { -1 => "danger", 0 => "rc-days-danger", 2 => "rc-days-danger", 3 => "rc-days-warning", 7 => "rc-days-warning", 8 => nil }.each do |days, days_class|
    it "keeps the Active chip consistent and uses #{days_class || 'default styling'} with #{days} days left" do
      sample.return_by = Date.current + days
      html = sample_html(previews_enabled: false)
      if days.negative?
        expect(html.at_css(".rc-card-top .rc-chip-danger")).to be_present
        expect(html.at_css(".rc-chip").text).to eq("Expired")
        expect(html.css(".rc-contract-details dd").map(&:text)).not_to include(days.to_s)
      else
        expect(html.at_css(".rc-card-top .rc-chip-success")).to be_present
        expect(html.at_css(".rc-chip").text).to eq("Active")
        days_cell = html.at_css(".rc-contract-details dd:last-child")
        expect(days_cell.text).to eq(days.to_s)
        if days_class
          expect(days_cell["class"]).to include(days_class)
        else
          expect(days_cell["class"]).to be_blank
        end
      end
      expect(html.css(".rc-card-bottom > .rc-muted")).to be_empty
      expect(html.css(".rc-days")).to be_empty
      expect(html.css(".rc-card-bottom > .rc-days")).to be_empty
      expect(html.at_css(".purchase-card")["data-status"]).to eq(days.negative? ? "expired" : "active")
    end
  end

  %w[returning shipped_back refund_pending keeping refunded].each do |status|
    it "keeps #{status} styling when its original deadline is today or overdue" do
      sample.status = status
      [ 0, -1 ].each do |days|
        sample.return_by = Date.current + days
        html = sample_html(previews_enabled: false)
        expect(html.css(".rc-chip-warning, .rc-chip-danger")).to be_empty
        expect(html.at_css(".rc-chip").text).to eq(I18n.t("ui.#{status}"))
        expect(html.at_css(".purchase-card")["data-status"]).to eq(status)
      end
    end
  end

  it "keeps the safe demo preview Edit button before the backend CRUD routes exist" do
    html = sample_html(previews_enabled: true)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.css(".rc-card-top button[data-action^='rc-purchase-preview#']").size).to eq(1)
    expect(html.css(".rc-card-actions form")).to be_empty
    expect(html.css(".rc-card-top > button.rc-card-edit").map { |button| button.text.strip }).to eq([ "Edit" ])
    expect(html.css(".rc-card-more")).to be_empty
  end

  it "links demo Edit to a new purchase template without exposing mutation actions" do
    html = sample_html(previews_enabled: false)
    expect(html.at_css(".purchase-card")["data-sample"]).to eq("true")
    expect(html.at_css(".rc-product-name").text).to eq("Demo Notebook")
    link = html.at_css(".rc-card-edit")
    expect(link.text.strip).to eq("Edit")
    expect(link["href"]).to eq(new_purchase_path(sample: sample.item_name))
    expect(html.css(".rc-card-actions form, .rc-card-actions details, [data-action^='rc-purchase-preview#']")).to be_empty
  end
end
