class Purchase < ApplicationRecord
  STATUSES = %w[
    active
    keeping
    returning
    shipped_back
    refund_pending
    refunded
    expired
  ].freeze

  # Statuses that still have a return decision to make before the deadline.
  OPEN_STATUSES = %w[active returning].freeze
  # Statuses shown on the Dashboard; everything else belongs in History.
  DASHBOARD_STATUSES = %w[active returning shipped_back refund_pending].freeze

  REOPEN_MESSAGE = "The return-by date has passed. Edit the return-by date to reopen this purchase.".freeze
  MISSING_DEADLINE_MESSAGE = "Add a return-by date, or a purchase date and return window".freeze

  belongs_to :user
  belongs_to :store_policy, optional: true

  normalizes :store_name, with: ->(name) { name.strip.presence }

  before_validation :resolve_return_by
  before_validation :link_store_policy
  before_validation :apply_deadline_to_status
  before_save :record_status_dates

  validates :item_name, presence: true
  validates :price, numericality: { greater_than: 0 }, allow_nil: true
  validates :return_window_days, numericality: { greater_than_or_equal_to: 0, message: "can't be negative" }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  validate :return_by_present
  validate :return_by_after_purchase_date
  validate :reopen_requires_new_deadline
  validate :store_policy_belongs_to_user

  # Marks open purchases whose return-by date has passed as expired.
  def self.expire_overdue!(today = Date.current)
    where(status: OPEN_STATUSES).where(return_by: ...today).update_all(status: "expired", updated_at: Time.current)
  end

  def self.on_dashboard
    where(status: DASHBOARD_STATUSES)
  end

  def self.in_history
    where.not(status: DASHBOARD_STATUSES)
  end

  def days_left
    return nil unless return_by

    (return_by - Date.current).to_i
  end

  def on_dashboard?
    DASHBOARD_STATUSES.include?(status)
  end

  # The saved policy for this store, matched without regard to capitalization.
  def matching_store_policy
    return unless store_name
    return store_policy if store_policy&.store_name&.casecmp?(store_name)

    user&.store_policies&.find_by("LOWER(store_name) = ?", store_name.downcase)
  end

  private

  # A filled-in return-by date wins; otherwise use the window, then the saved store's window.
  def resolve_return_by
    # A policy assigned directly names the store unless the store was also changed.
    if store_policy && (store_name.nil? || (will_save_change_to_store_policy_id? && !will_save_change_to_store_name?))
      self.store_name = store_policy.store_name
    end
    # Editing only the purchase date or window moves the deadline with it.
    self.return_by = nil if window_moved_without_deadline?

    if return_by
      self.return_window_days = (return_by - purchase_date).to_i if purchase_date && return_by >= purchase_date
    elsif purchase_date && return_window_days
      self.return_by = purchase_date + return_window_days if return_window_days >= 0
    elsif purchase_date && (policy = matching_store_policy)
      self.return_window_days = policy.window_days
      self.return_by = purchase_date + policy.window_days
    end
  end

  def window_moved_without_deadline?
    persisted? && purchase_date && return_window_days && !will_save_change_to_return_by? &&
      (will_save_change_to_purchase_date? || will_save_change_to_return_window_days?)
  end

  # Keeps an existing link while the store is unchanged, even after the policy's window is edited.
  def link_store_policy
    policy = matching_store_policy
    return if policy && policy == store_policy && !will_save_change_to_return_window_days?

    self.store_policy = (policy if policy&.window_days == return_window_days)
  end

  def apply_deadline_to_status
    return unless return_by

    if status == "expired" && !will_save_change_to_status? && return_by >= Date.current
      self.status = "active"
    elsif OPEN_STATUSES.include?(status) && return_by < Date.current && (new_record? || !will_save_change_to_status?)
      self.status = "expired"
    end
  end

  def record_status_dates
    return unless will_save_change_to_status?

    self.returned_at ||= Date.current if %w[shipped_back refund_pending].include?(status)
    self.refunded_at = Date.current if status == "refunded"
  end

  def return_by_present
    errors.add(:base, MISSING_DEADLINE_MESSAGE) unless return_by
  end

  def return_by_after_purchase_date
    return unless return_by && purchase_date

    errors.add(:return_by, "can't be before the purchase date") if return_by < purchase_date
  end

  def reopen_requires_new_deadline
    return if new_record? || !will_save_change_to_status? || !OPEN_STATUSES.include?(status)

    errors.add(:base, REOPEN_MESSAGE) if return_by && return_by < Date.current
  end

  def store_policy_belongs_to_user
    return unless user && store_policy

    if store_policy.user != user
      errors.add(:store_policy, "must belong to the same user")
    end
  end
end
