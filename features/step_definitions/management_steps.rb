Given("the account {string} has a purchase named {string} from {string} with a {int}-day return window") do |email, name, store, days|
  user = User.find_by!(email_address: email)
  policy = user.store_policies.create!(store_name: store, window_days: days)
  user.purchases.create!(item_name: name, price: "49.99", purchase_date: Date.current, store_policy: policy)
end

Given("the account {string} has a policy named {string} with a {int}-day return window") do |email, name, days|
  User.find_by!(email_address: email).store_policies.create!(store_name: name, window_days: days)
end

When("I edit purchase {string}") do |name|
  within(find(".purchase-card", text: name, exact_text: false)) { click_link "Edit", exact: true }
end

When("I save the purchase as {string} costing {string} bought {int} days ago using {string}") do |name, price, days, store|
  fill_in "Item Name", with: name
  fill_in "Price", with: price
  fill_in "Purchase Date", with: (Date.current - days).iso8601
  select store, from: "Store Policy"
  click_button "Save Purchase"
end

When("I set purchase {string} to status {string}") do |name, status|
  within(find(".purchase-card", text: name, exact_text: false)) { click_link "Edit", exact: true }
  select status, from: "Status"
  click_button "Save Purchase"
end

When("I ask to delete purchase {string}") do |name|
  within(find(".purchase-card", text: name, exact_text: false)) { click_link "Delete", exact: true }
end

When("I confirm purchase deletion") do
  click_button "Delete Purchase"
end

When("I change policy {string} to a {int}-day return window") do |name, days|
  within(find(".purchase-card", text: name, exact_text: false)) { click_link "Edit Store Policy" }
  fill_in "Return Window (days)", with: days
  click_button "Save Store Policy"
end

When("I choose store policy {string}") do |store|
  select store, from: "Store Policy"
end

Then("purchase {string} should have a deadline {int} days from today") do |name, days|
  card = find(".purchase-card", text: /\A#{Regexp.escape(name)}\s/)
  expect(card).to have_selector("time[datetime='#{(Date.current + days).iso8601}']")
end

Then("I should not see a purchase named {string}") do |name|
  expect(page).not_to have_selector(".purchase-card h2", exact_text: name)
end
