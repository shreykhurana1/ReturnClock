class StorePolicy < ApplicationRecord
  belongs_to :user
  has_many :purchases, dependent: :restrict_with_error

  validates :store_name,
            presence: true,
            uniqueness: { scope: :user_id }

  validates :window_days,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validate :owner_cannot_change_with_purchases, on: :update

  private

  def owner_cannot_change_with_purchases
    if will_save_change_to_user_id? && purchases.exists?
      errors.add(:user, "cannot change while purchases reference this policy")
    end
  end
end
