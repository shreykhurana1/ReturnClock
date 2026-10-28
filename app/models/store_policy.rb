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
end
