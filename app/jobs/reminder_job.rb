class ReminderJob < ApplicationJob
  queue_as :default

  # Emails each open purchase once when its deadline is within the owner's reminder lead time.
  def perform(today = Date.current)
    Purchase.expire_overdue!(today)
    return unless Rails.configuration.x.reminder_emails_enabled

    Purchase.joins(:user).includes(:user)
      .where(status: Purchase::OPEN_STATUSES, reminded_at: nil)
      .where("purchases.return_by - users.reminder_days_before <= ?", today)
      .find_each do |purchase|
        ReminderMailer.return_deadline(purchase).deliver_now
        purchase.update_columns(reminded_at: Time.current)
      end
  end
end
