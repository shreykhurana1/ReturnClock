require "rails_helper"

RSpec.describe "purchases/_form", type: :view do
  let(:user) { User.create!(email_address: "form@example.com", password: "Password1!") }
  let(:purchase) { user.purchases.build(purchase_date: Date.current, status: "active") }

  before do
    Current.session = Session.new(user: user)
    # Test the prepared template without adding teammates' production routes.
    allow(view).to receive(:polymorphic_path).and_return("/purchases")
  end

  after { Current.reset }

  def form_html
    render partial: "purchases/form", locals: { purchase: purchase }
    Nokogiri::HTML.fragment(rendered)
  end

  it "offers new-policy inputs for a user without policies and omits derived/owner fields" do
    html = form_html
    expect(html.at_css("form")["method"]).to eq("post")
    expect(html.at_css("input[name='store_policy[store_name]']")["required"]).to be_present
    expect(html.at_css("input[name='store_policy[store_name]']")["disabled"]).to be_nil
    expect(html.at_css("select[name='purchase[store_policy_id]']")["disabled"]).to be_present
    expect(html.at_css("input[name='purchase[status]']")["value"]).to eq("active")
    expect(html.css("[name='purchase[user_id]'], [name='purchase[return_by]']")).to be_empty
  end

  it "offers only the current user's policies and disables hidden new-policy inputs" do
    policy = user.store_policies.create!(store_name: "Own Store", window_days: 30)
    other = User.create!(email_address: "private@example.com", password: "Password1!")
    other.store_policies.create!(store_name: "Private Store", window_days: 60)
    html = form_html
    select = html.at_css("select[name='purchase[store_policy_id]']")
    expect(select.css("option").map { |option| option["value"] }).to eq([ "", policy.id.to_s ])
    expect(select["required"]).to be_present
    expect(select["disabled"]).to be_nil
    expect(html.at_css("input[name='store_policy[store_name]']")["disabled"]).to be_present
    expect(rendered).not_to include("Private Store")
  end

  it "preserves rejected policy input and displays escaped validation errors" do
    user.store_policies.create!(store_name: "Existing Store", window_days: 30)
    view.params[:store_policy] = { store_name: "<script>bad()</script>", window_days: "0" }
    purchase.errors.add(:item_name, "<script>bad()</script>")
    html = form_html
    expect(html.at_css("[role='alert']").text).to include("bad()")
    expect(html.css("script")).to be_empty
    expect(html.at_css("input[name='store_policy[store_name]']")["value"]).to eq("<script>bad()</script>")
    expect(html.at_css("input[name='store_policy[store_name]']")["disabled"]).to be_nil
    expect(html.at_css("select[name='purchase[store_policy_id]']")["disabled"]).to be_present
  end

  it "renders the edit values, PATCH method and existing status choices" do
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    purchase.update!(item_name: "Notebook", price: "19.99", store_policy: policy, status: "keeping")
    allow(view).to receive(:polymorphic_path).and_return("/purchases/#{purchase.id}")
    html = form_html
    expect(html.at_css("form")["action"]).to eq("/purchases/#{purchase.id}")
    expect(html.at_css("input[name='_method']")["value"]).to eq("patch")
    expect(html.at_css("input[name='purchase[item_name]']")["value"]).to eq("Notebook")
    expect(html.css("select[name='purchase[status]'] option").map { |option| option["value"] }).to eq(%w[active keeping refunded])
    expect(html.at_css("select[name='purchase[status]'] option[selected]")["value"]).to eq("keeping")
  end

  it "preserves an existing legacy status without offering it as a manual choice" do
    policy = user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    purchase.update!(item_name: "Notebook", price: 15, store_policy: policy, status: "returning")
    html = form_html
    selected = html.at_css("select[name='purchase[status]'] option[selected]")
    expect(selected["value"]).to eq("returning")
    expect(selected["disabled"]).not_to be_nil
    expect(html.css("select[name='purchase[status]'] option:not([disabled])").map { |option| option["value"] }).to eq(%w[active keeping refunded])
  end
end
