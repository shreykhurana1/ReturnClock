QUICK_BUTTONS = [ "Keep it", "Return it", "Sent it back", "Refund received" ].freeze

# Urgency and outcome names map onto the existing status chip colors.
CHIP_COLORS = {
  "urgent" => "danger",
  "soon" => "warning",
  "safe" => "success",
  "awaiting" => "blue",
  "kept" => "secondary",
  "refunded" => "success",
  "expired" => "danger"
}.freeze

When("I press {string} on the {string} card") do |label, name|
  within(card_named(name)) { click_on label, exact: true }
end

Then("the {string} card should show {string}") do |name, text|
  expect(card_named(name)).to have_text(text)
end

Then("the {string} card should not show {string}") do |name, text|
  expect(card_named(name)).not_to have_text(text)
end

Then("the {string} card should show store {string}") do |name, store|
  expect(card_named(name)).to have_text(store)
end

Then("the {string} card should show return date {string}") do |name, date|
  expect(card_named(name)).to have_selector("time[datetime='#{Date.parse(date).iso8601}']")
end

Then("the {string} card should not show a price") do |name|
  expect(card_named(name)).not_to have_text("$")
end

Then("the {string} card should show {string} with the date {string}") do |name, label, date|
  expect(card_named(name)).to have_text("#{label} #{I18n.l(Date.parse(date), format: :long)}")
end

Then("the {string} card should be marked {string}") do |name, marking|
  expect(card_named(name)).to have_selector(".rc-chip.rc-chip-#{CHIP_COLORS.fetch(marking)}")
end

Then("the {string} card should only offer {string}") do |name, offered|
  expected = offered.split(",").map(&:strip)
  within(card_named(name)) do
    QUICK_BUTTONS.each do |label|
      if expected.include?(label)
        expect(page).to have_button(label, exact: true)
      else
        expect(page).not_to have_button(label, exact: true)
      end
    end
  end
end

Then("I should see {string} before {string}") do |first, second|
  names = page.all(".purchase-card h2").map(&:text)
  expect(names.index(first)).to be < names.index(second)
end

Then("the {string} stat should show {string}") do |title, value|
  expect(find(".rc-stat", text: title)).to have_text(value)
end
