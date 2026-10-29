class Purchase < ApplicationRecord
  STATUSES = %w[
    active
    keeping
    returning
    shipped_back
    refund_pending
    refunded
  ].freeze

  belongs_to :user
  belongs_to :store_policy

  before_validation :calculate_return_by,
                    if: :deadline_needs_calculation?

  validates :item_name, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :purchase_date, presence: true
  validates :return_by, presence: true
  validates :status, inclusion: { in: STATUSES }

  validate :store_policy_belongs_to_user

  def days_left
    return nil unless return_by

    (return_by - Date.current).to_i
  end

  private

  def deadline_needs_calculation?
    new_record? ||
      will_save_change_to_purchase_date? ||
      will_save_change_to_store_policy_id?
  end

  def calculate_return_by
    return unless purchase_date && store_policy&.window_days

    self.return_by = purchase_date + store_policy.window_days
  end

  def store_policy_belongs_to_user
    return unless user && store_policy

    if store_policy.user != user
      errors.add(:store_policy, "must belong to the same user")
    end
  end
end
