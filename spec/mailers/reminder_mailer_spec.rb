require "rails_helper"

RSpec.describe ReminderMailer, type: :mailer do
  let(:user) { User.create!(email_address: "someone@example.com", password: "Password1!") }
  let(:policy) { user.store_policies.create!(store_name: "Target", window_days: 30) }
  let(:purchase) do
    user.purchases.create!(store_policy: policy, item_name: "Jacket", price: 20, purchase_date: Date.new(2026, 11, 30))
  end
  let(:mail) { described_class.return_deadline(purchase) }

  it "is addressed to the owner with the item, store and deadline in the subject" do
    expect(mail.to).to eq([ "someone@example.com" ])
    expect(mail.subject).to eq("Return Jacket to Target by Dec 30, 2026")
  end

  it "names the item, store and deadline and links to the dashboard in both formats" do
    text = mail.text_part.body.to_s
    html = mail.html_part.body.to_s
    expect(text).to include("Jacket from Target must be returned by Dec 30, 2026.", dashboard_url)
    expect(html).to include("<strong>Jacket</strong> from Target must be returned by Dec 30, 2026.")
    expect(Nokogiri::HTML(html).at_css("a[href='#{dashboard_url}']").text).to eq("Open ReturnClock")
  end

  it "escapes markup in the item name" do
    purchase.update!(item_name: "<script>alert(1)</script>")
    html = described_class.return_deadline(purchase).html_part.body.to_s
    expect(html).not_to include("<script>")
    expect(html).to include("&lt;script&gt;")
  end
end
