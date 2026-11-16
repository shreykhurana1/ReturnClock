class ReminderJob < ApplicationJob
  queue_as :default

  # Emails each open purchase once when its deadline is within the owner's reminder lead time.
  # "Today" is each owner's own date unless one is passed in.
  def perform(today = nil)
    User.find_each do |user|
      Time.use_zone(user.time_zone) do
        remind(user, today || Date.current)
      end
    end
  end

  private

  def remind(user, today)
    user.purchases.expire_overdue!(today)
    return unless Rails.configuration.x.reminder_emails_enabled

    user.purchases.where(status: Purchase::OPEN_STATUSES, reminded_at: nil)
      .where("purchases.return_by - ?::integer <= ?", user.reminder_days_before, today)
      .find_each do |purchase|
        ReminderMailer.return_deadline(purchase).deliver_now
        purchase.update_columns(reminded_at: Time.current)
      end
  end
end
