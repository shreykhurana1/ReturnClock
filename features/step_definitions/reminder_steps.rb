Given(/^today is (\d{4}-\d{2}-\d{2})$/) do |date|
  travel_to Time.zone.parse(date).change(hour: 12)
end

Given("a user {string} who wants reminders {int} days before") do |email, days|
  @user = User.create!(email_address: email, password: "Password1!", password_confirmation: "Password1!",
    reminder_days_before: days)
end

Given("{string} wants reminders {int} days before") do |email, days|
  User.find_by!(email_address: email).update!(reminder_days_before: days)
end

When("the reminder job runs") do
  ReminderJob.perform_now
end

Then("{string} should receive {int} email(s)") do |email, count|
  expect(ActionMailer::Base.deliveries.count { |mail| mail.to.include?(email) }).to eq(count)
end

Then("{string} should receive no emails") do |email|
  expect(ActionMailer::Base.deliveries.count { |mail| mail.to.include?(email) }).to eq(0)
end

Then("that email's subject should be {string}") do |subject|
  expect(ActionMailer::Base.deliveries.map(&:subject)).to eq([ subject ])
end

Then("one email's subject should be {string}") do |subject|
  expect(ActionMailer::Base.deliveries.map(&:subject)).to include(subject)
end
