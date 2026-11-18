class ReminderJob < ApplicationJob
  queue_as :default

  # Emails each open purchase once when its deadline is within the owner's reminder lead time.
  def perform(today = Date.current)
    return unless Rails.configuration.x.reminder_emails_enabled

    Purchase.joins(:user).includes(:user, :store_policy)
      .where(status: Purchase::OPEN_STATUSES, reminded_at: nil, return_by: today..)
      .where("purchases.return_by - users.reminder_days_before <= ?", today)
      .find_each do |purchase|
        ReminderMailer.return_deadline(purchase).deliver_now
        purchase.update_columns(reminded_at: Time.current)
      end
  end
end
