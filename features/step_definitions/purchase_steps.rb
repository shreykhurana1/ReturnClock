When("I create a store policy named {string} with a {int}-day return window") do |name, days|
  fill_in "Store Name", with: name
  fill_in "Return Window (days)", with: days
  click_button "Create Store Policy"
end

Then("the store policy {string} should be selected") do |name|
  expect(page).to have_select("Store Policy", selected: name)
end

When("I add a purchase named {string} costing {string} purchased today") do |name, price|
  fill_in "Item Name", with: name
  fill_in "Price", with: price
  fill_in "Purchase Date", with: Date.current.iso8601
  click_button "Add Purchase"
end

Then("the purchase should have a return deadline {int} days from today") do |days|
  expect(page).to have_selector(".purchase-card time[datetime='#{(Date.current + days).iso8601}']")
end

When("I choose purchase status {string}") do |status|
  select status, from: "Status"
end

Then("the purchase status {string} should be selected") do |status|
  expect(page).to have_select("Status", selected: status)
end

Then("the purchase price should be {string}") do |price|
  expect(BigDecimal(find_field("Price").value)).to eq(BigDecimal(price))
end

When("I correct the item name to {string}") do |name|
  fill_in "Item Name", with: name
  click_button "Add Purchase"
end
