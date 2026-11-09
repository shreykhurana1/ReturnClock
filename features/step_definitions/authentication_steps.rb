PAGE_PATHS = {
  "Dashboard" => :dashboard_path,
  "History" => :history_path,
  "Store Policies" => :store_policies_path,
  "Add Purchase" => :new_purchase_path,
  "Account Settings" => :settings_path
}.freeze

Given("a user exists with email {string} and password {string}") do |email, password|
  User.create!(email_address: email, password: password, password_confirmation: password)
end

Given("I am logged in as {string}") do |email|
  @user = User.find_by(email_address: email) ||
    User.create!(email_address: email, password: "Password1!", password_confirmation: "Password1!")
  visit new_session_path
  fill_in "Email", with: email
  fill_in "Password", with: "Password1!", exact: true
  click_button "Sign In"
end

Given("I am not logged in") do
  # Nothing to do: each scenario starts without a session.
end

Given("I visit the landing page") do
  visit root_path
end

When(/^I (?:go to|am on) (?:the )?(Dashboard|History|Store Policies|Add Purchase|Account Settings)(?: page)?$/) do |page_name|
  visit send(PAGE_PATHS.fetch(page_name))
end

When("I follow {string}") do |label|
  click_link label, exact: true
end

When("I press {string}") do |label|
  click_button label, exact: true
end

When("I fill in {string} with {string}") do |label, value|
  fill_in label, with: value, exact: true
end

When("I select {string} from {string}") do |option, label|
  select option, from: label
end

When("I sign up with email {string} and password {string}") do |email, password|
  fill_in "Email", with: email
  fill_in "Password", with: password, exact: true
  fill_in "Confirm Password", with: password
  click_button "Create Account"
end

When("I log in with email {string} and password {string}") do |email, password|
  fill_in "Email", with: email
  fill_in "Password", with: password, exact: true
  click_button "Sign In"
end

When("I open the profile menu") do
  find("summary[aria-label='Profile menu']").click
end

Then(/^I should be on (?:the )?(.+?)(?: page)?$/) do |heading|
  expect(page).to have_selector("main h1", exact_text: heading)
end

Then("I should see {string} in the main content") do |text|
  within("main") { expect(page).to have_text(text) }
end

Then("I should not see {string} in the main content") do |text|
  within("main") { expect(page).not_to have_text(text) }
end

Then("the {string} field should contain {string}") do |label, value|
  expect(find_field(label, exact: true).value.to_s).to eq(value)
end

Then("the {string} field should be set to {string}") do |label, value|
  expect(page).to have_select(label, selected: value)
end
