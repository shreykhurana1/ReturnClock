When("I save the purchase as {string} costing {string} bought {int} days ago using {string}") do |name, price, days, store|
  fill_in "Item Name", with: name
  fill_in "Price", with: price
  fill_in "Purchase Date", with: (Date.current - days).iso8601
  fill_in "Store", with: store, exact: true
  # Clear the stored deadline so the saved store's window sets the new one.
  fill_in "Return Window (days)", with: ""
  fill_in "Return By", with: ""
  click_button "Save Purchase"
end

When("I set purchase {string} to status {string}") do |name, status|
  within(find(".purchase-card", text: name, exact_text: false)) { click_link "Edit", exact: true }
  select status, from: "Status"
  click_button "Save Purchase"
end

When("I quickly update purchase {string} to status {string}") do |name, status|
  within(card_named(name)) do
    find("summary").click
    select status, from: "Update status"
    click_button "Confirm status"
  end
end

Then("purchase {string} should show status {string}") do |name, status|
  within(card_named(name)) do
    expect(page).to have_selector(".rc-chip", exact_text: status)
  end
end

When("I ask to delete purchase {string}") do |name|
  within(card_named(name)) do
    find("summary").click
    click_link "Delete", exact: true
  end
end

When("I confirm purchase deletion") do
  click_button "Delete Purchase"
end

When("I change policy {string} to a {int}-day return window") do |name, days|
  within(card_named(name)) { click_link "Edit Store Policy" }
  fill_in "Return Window (days)", with: days
  click_button "Save Store Policy"
end

Then("purchase {string} should have a deadline {int} days from today") do |name, days|
  expect(card_named(name)).to have_selector("time[datetime='#{(Date.current + days).iso8601}']")
end

Then("I should not see a purchase named {string}") do |name|
  expect(page).not_to have_selector(".purchase-card h2", exact_text: name)
end
