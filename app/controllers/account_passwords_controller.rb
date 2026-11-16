class AccountPasswordsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, by: -> { Current.user.id }, only: :update,
    with: -> { redirect_to settings_path, alert: "Too many password change attempts. Try again later.", status: :see_other }

  def update
    attributes = params.expect(user: [ :current_password, :password, :password_confirmation ])
      .transform_values { |value| value.is_a?(String) ? value : "" }
    @user = Current.user
    changed = false

    # Check the latest password while holding the user lock. Save and revoke
    # sessions in the same transaction so they succeed or fail together.
    @user.with_lock do
      validate_password_fields(attributes)
      if @user.errors.empty? && @user.update(attributes.slice(:password, :password_confirmation))
        @user.sessions.destroy_all
        changed = true
      end
    end

    if changed
      reset_session
      cookies.delete(:session_id)
      Current.reset
      redirect_to new_session_path, notice: "Password changed. Please sign in again.", status: :see_other
    else
      @user.errors.add(:base, "Your password could not be changed. Please try again.") if @user.errors.empty?
      render "settings/show", status: :unprocessable_entity
    end
  end

  private

  def validate_password_fields(attributes)
    if attributes[:current_password].blank?
      @user.errors.add(:current_password, "Enter your current password.")
    elsif !@user.authenticate(attributes[:current_password])
      @user.errors.add(:current_password, "Current password is incorrect.")
    end

    @user.errors.add(:password, :blank) if attributes[:password].blank?
    if attributes[:password_confirmation].blank?
      @user.errors.add(:password_confirmation, :blank, message: "Confirm your new password.")
    end
  end
end
