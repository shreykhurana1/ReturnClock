Given("the account {string} has these purchases:") do |email, table|
  user = User.find_by!(email_address: email)
  table.hashes.each do |row|
    policy = user.store_policies.find_or_create_by!(store_name: row.fetch("store")) do |record|
      record.window_days = Integer(row.fetch("return window"))
    end
    user.purchases.create!(item_name: row.fetch("item"), price: "20.00", store_policy: policy,
      purchase_date: Date.current - Integer(row.fetch("days ago")), status: row.fetch("status").downcase.tr(" ", "_"))
  end
end

Then("the available store policies should be:") do |table|
  expect(page).to have_select("Store Policy", options: [ "Select a store policy" ] + table.raw.flatten)
end

Then("the purchases should appear in this order:") do |table|
  expect(page.all(".purchase-card h2").map(&:text)).to eq(table.raw.flatten)
end

When("I open the purchase editor for {string} belonging to {string}") do |name, email|
  owner = User.find_by!(email_address: email)
  visit edit_purchase_path(owner.purchases.find_by!(item_name: name))
end

When("I open the policy editor for {string} belonging to {string}") do |name, email|
  owner = User.find_by!(email_address: email)
  visit edit_store_policy_path(owner.store_policies.find_by!(store_name: name))
end

Then("I should see a page-not-found response") do
  expect(page.status_code).to eq(404)
  expect(page).to have_text("The page you were looking for doesn't exist.")
  expect(page).not_to have_field("Item Name")
  expect(page).not_to have_field("Store Name")
end
