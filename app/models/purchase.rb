class Purchase < ApplicationRecord
  STATUSES = %w[
    active
    keeping
    returning
    shipped_back
    refund_pending
    refunded
  ].freeze

  # Statuses that still have a return decision to make before the deadline.
  OPEN_STATUSES = %w[active returning].freeze

  # Days before the deadline when an active purchase turns urgent (unless the user picks their own
  # lead time), then merely soon.
  URGENT_DAYS = 2
  SOON_DAYS = 7

  belongs_to :user
  belongs_to :store_policy

  before_save :record_status_dates
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

  # How pressing an active purchase's deadline is; nil once it is decided or overdue.
  def urgency(urgent_days = user&.reminder_days_before || URGENT_DAYS)
    return unless status == "active" && days_left && days_left >= 0

    if days_left <= urgent_days then :urgent
    elsif days_left <= SOON_DAYS then :soon
    else :later
    end
  end

  private

  # Remembers when a return was sent and when the refund arrived.
  def record_status_dates
    return unless will_save_change_to_status?

    case status
    when "active", "keeping", "returning"
      self.returned_at = nil
      self.refunded_at = nil
    when "shipped_back"
      self.returned_at = Date.current
      self.refunded_at = nil
    when "refund_pending"
      # Preserve a known shipment date, but do not invent one for a directly recorded refund.
      self.refunded_at = nil
    when "refunded"
      self.refunded_at = Date.current
    end
  end

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
