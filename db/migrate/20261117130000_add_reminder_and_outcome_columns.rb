class AddReminderAndOutcomeColumns < ActiveRecord::Migration[8.1]
  # Additive only: a defaulted user setting and nullable purchase dates, with no backfill.
  def change
    add_column :users, :reminder_days_before, :integer, null: false, default: 2
    add_column :purchases, :returned_at, :date
    add_column :purchases, :refunded_at, :date
    add_column :purchases, :reminded_at, :datetime
  end
end
