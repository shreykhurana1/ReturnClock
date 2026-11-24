When("I set deadline alerts to {string}") do |preference|
  select preference, from: "Alert me"
  click_button "Save settings"
end

Then("purchase {string} should show a/an {string} deadline indicator") do |name, color|
  classes = { "amber" => "rc-days-warning", "red" => "rc-days-danger" }
  card = find(".purchase-card h2", exact_text: name).ancestor(".purchase-card")
  expect(card).to have_selector(".rc-card-top .rc-chip-success", exact_text: "Active")
  expect(card).to have_selector(".#{classes.fetch(color)}")
end

When("I choose {string} for purchase {string}") do |action, name|
  within(find(".purchase-card h2", exact_text: name).ancestor(".purchase-card")) do
    click_button action, exact: true
  end
end

Then("purchase {string} should show {string} dated today") do |name, label|
  card = find(".purchase-card h2", exact_text: name).ancestor(".purchase-card")
  expect(card).to have_selector(".rc-outcome", text: label)
  expect(card).to have_selector(".rc-outcome time[datetime='#{Date.current.iso8601}']")
end
