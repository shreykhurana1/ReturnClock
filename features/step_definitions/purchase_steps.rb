Given("I have the following purchases:") do |table|
  create_purchases(@user, table)
end

Given("{string} has the following purchases:") do |email, table|
  create_purchases(User.find_by!(email_address: email), table)
end

Given("I have a purchase {string} from {string} with a {int} day return window") do |name, store, days|
  policy = @user.store_policies.create!(store_name: store, window_days: days)
  @user.purchases.create!(item_name: name, store_name: store, price: "49.99", purchase_date: Date.current, store_policy: policy)
end

Given("I have a saved store {string} with a {int} day return window") do |store, days|
  @user.store_policies.create!(store_name: store, window_days: days)
end

Given("{string} has status {string}") do |name, status|
  # Skip validations so a scenario can start from any status.
  Purchase.find_by!(item_name: name).update_columns(status: status_value(status))
end

When("I add a purchase {string} from store {string} with a {int} day window") do |name, store, days|
  visit new_purchase_path
  fill_in "Item Name", with: name
  fill_in "Store", with: store, exact: true
  fill_in "Return Window (days)", with: days
  click_button "Add Purchase"
end

When("I create a store policy named {string} with a {int}-day return window") do |name, days|
  fill_in "Store Name", with: name
  fill_in "Return Window (days)", with: days
  click_button "Create Store Policy"
end

When("I add a purchase named {string} costing {string} purchased today") do |name, price|
  fill_in "Item Name", with: name
  fill_in "Price", with: price
  fill_in "Purchase Date", with: Date.current.iso8601
  click_button "Add Purchase"
end

When("I correct the item name to {string}") do |name|
  fill_in "Item Name", with: name
  click_button "Add Purchase"
end

Then("the purchase should have a return deadline {int} days from today") do |days|
  expect(page).to have_selector(".purchase-card time[datetime='#{(Date.current + days).iso8601}']")
end

Then("the purchase price should be {string}") do |price|
  expect(BigDecimal(find_field("Price").value)).to eq(BigDecimal(price))
end

Then("I should not see the save-store banner") do
  within("main") { expect(page).not_to have_text(/Save store ".*" with a \d+ day return window\?/) }
end

Then("the store policy {string} should have a {int} day return window") do |store, days|
  expect(card_named(store)).to have_text("Return window: #{days} days")
end

Then("the store policy {string} should be in use") do |store|
  expect(card_named(store)).to have_text("In use by purchases; cannot be deleted.")
end
