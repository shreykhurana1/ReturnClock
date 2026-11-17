class StorePolicy < ApplicationRecord
  belongs_to :user
  has_many :purchases, dependent: :restrict_with_error

  # A store can have several policies, as long as each has its own window.
  validates :store_name, presence: true
  validates :store_name,
            uniqueness: { scope: [ :user_id, :window_days ], case_sensitive: false, message: "already has a policy with that return window" }

  validates :window_days,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validate :owner_cannot_change_with_purchases, on: :update

  # Distinguishes a store's policies in lists, e.g. "Zara — 30 days".
  def label
    "#{store_name} — #{window_days} #{"day".pluralize(window_days)}"
  end

  private

  def owner_cannot_change_with_purchases
    if will_save_change_to_user_id? && purchases.exists?
      errors.add(:user, "cannot change while purchases reference this policy")
    end
  end
end
