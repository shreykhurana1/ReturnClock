namespace :reminders do
  desc "Expire overdue purchases and email return reminders"
  task run: :environment do
    ReminderJob.perform_now
  end
end
