class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :store_policies, dependent: :destroy

  REMINDER_OPTIONS = { "1 day before" => 1, "2 days before" => 2, "3 days before" => 3, "1 week before" => 7 }.freeze

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :reminder_days_before, inclusion: { in: REMINDER_OPTIONS.values }

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
