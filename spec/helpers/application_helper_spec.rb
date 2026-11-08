require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#purchase_preview_enabled?" do
    before do
      allow(helper).to receive(:respond_to?).and_call_original
      %i[new_purchase_path edit_purchase_path purchase_path].each do |route|
        allow(helper).to receive(:respond_to?).with(route).and_return(true)
      end
    end

    it "disables previews once all three purchase CRUD route helpers exist" do
      expect(helper.purchase_preview_enabled?).to be(false)
    end

    it "keeps previews while at least one purchase CRUD route is missing" do
      allow(helper).to receive(:respond_to?).with(:purchase_path).and_return(false)
      expect(helper.purchase_preview_enabled?).to be(true)
    end
  end
end
