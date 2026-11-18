namespace :reminders do
  desc "Email return reminders"
  task run: :environment do
    ReminderJob.perform_now
  end
end
