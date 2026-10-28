class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :store_policies, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
            length: { minimum: 8 },
            if: -> { password.present? }

  validate :password_requirements, if: -> { password.present? }

  private

  def password_requirements
    valid_format =
      password.match?(/[A-Z]/) &&
      password.match?(/[a-z]/) &&
      password.match?(/[0-9]/) &&
      password.match?(/[^A-Za-z0-9\s]/)

    unless valid_format
      errors.add(:password, "must include an uppercase letter, a lowercase letter, a number, and a special character")
    end
  end
end
