Given("an account exists for {string} with password {string}") do |email, password|
  User.create!(email_address: email, password: password, password_confirmation: password)
end

Given("I visit the landing page") do
  visit root_path
end

When("I visit the Dashboard directly") do
  visit dashboard_path
end

When("I visit History directly") do
  visit history_path
end

When("I follow {string}") do |label|
  click_link label, exact: true
end

When("I sign up with email {string} and password {string}") do |email, password|
  fill_in "Email", with: email
  fill_in "Password", with: password, exact: true
  fill_in "Confirm Password", with: password
  click_button "Create Account"
end

When("I sign in with email {string} and password {string}") do |email, password|
  fill_in "Email", with: email
  fill_in "Password", with: password, exact: true
  click_button "Sign In"
end

When("I open the profile menu") do
  find("summary[aria-label='Profile menu']").click
end

When("I sign out") do
  click_button "Sign Out"
end

Then("I should see the {string} heading") do |heading|
  expect(page).to have_selector("main h1", exact_text: heading)
end

Then("I should see {string} in the main content") do |text|
  within("main") { expect(page).to have_text(text) }
end

Then("the {string} field should contain {string}") do |label, value|
  expect(find_field(label, exact: true).value.to_s).to eq(value)
end
