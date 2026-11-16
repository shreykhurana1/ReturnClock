class StorePolicy < ApplicationRecord
  belongs_to :user
  has_many :purchases, dependent: :restrict_with_error

  validates :store_name,
            presence: true,
            uniqueness: { scope: :user_id, case_sensitive: false }

  validates :window_days,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validate :owner_cannot_change_with_purchases, on: :update

  after_create :link_matching_purchases

  private

  def owner_cannot_change_with_purchases
    if will_save_change_to_user_id? && purchases.exists?
      errors.add(:user, "cannot change while purchases reference this policy")
    end
  end

  # Purchases logged before the store was saved join the new policy when their window matches.
  def link_matching_purchases
    user.purchases.where(store_policy_id: nil, return_window_days: window_days)
      .where("LOWER(store_name) = ?", store_name.downcase)
      .update_all(store_policy_id: id)
  end
end
