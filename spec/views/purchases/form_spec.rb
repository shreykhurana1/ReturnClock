require "rails_helper"

RSpec.describe "purchases/_form", type: :view do
  let(:user) { User.create!(email_address: "form@example.com", password: "Password1!") }
  let(:purchase) { user.purchases.build(purchase_date: Date.current, status: "active") }

  before { Current.session = Session.new(user: user) }
  after { Current.reset }

  def form_html
    render partial: "purchases/form", locals: { purchase: purchase }
    Nokogiri::HTML.fragment(rendered)
  end

  it "guides an account without policies to policy creation and disables purchase submission" do
    html = form_html
    expect(html.at_css("a[href='#{new_store_policy_path(origin: "purchase")}']").text).to eq("Create Store Policy")
    expect(html.at_css("input[type='submit']")["disabled"]).to be_present
    expect(html.css("[name^='store_policy['], [name='purchase[user_id]'], [name='purchase[return_by]']")).to be_empty
  end

  it "offers only the current user's saved policies" do
    policy = user.store_policies.create!(store_name: "Own Store", window_days: 30)
    other = User.create!(email_address: "private@example.com", password: "Password1!")
    other.store_policies.create!(store_name: "Private Store", window_days: 60)
    html = form_html
    select = html.at_css("select[name='purchase[store_policy_id]']")
    expect(select.css("option").map { |option| option["value"] }).to eq([ "", policy.id.to_s ])
    expect(select["required"]).to be_present
    expect(rendered).not_to include("Private Store")
  end

  it "escapes rejected purchase values and validation errors" do
    user.store_policies.create!(store_name: "Own Store", window_days: 30)
    purchase.item_name = "<script>bad()</script>"
    purchase.errors.add(:item_name, "<script>bad()</script>")
    html = form_html
    expect(html.at_css("[role='alert']").text).to include("bad()")
    expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq(purchase.item_name)
    expect(html.css("script")).to be_empty
  end

  it "renders editable values, PATCH and all backend-supported statuses" do
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    purchase.update!(item_name: "Notebook", price: "19.99", store_policy: policy, status: "returning")
    html = form_html
    expect(html.at_css("form")["action"]).to eq(purchase_path(purchase))
    expect(html.at_css("input[name='_method']")["value"]).to eq("patch")
    expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Notebook")
    expect(html.css("select[name='purchase[status]'] option").map { |option| option["value"] }).to eq(Purchase::STATUSES)
    expect(html.at_css("select[name='purchase[status]'] option[selected]")["value"]).to eq("returning")
    expect(html.css("select[name='purchase[status]'] option[disabled]")).to be_empty
  end
end
