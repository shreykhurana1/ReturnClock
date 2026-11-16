class SettingsController < ApplicationController
  before_action :ensure_reminder_emails_enabled, only: :update

  def show
  end

  def update
    if Current.user.update(params.expect(user: [ :reminder_days_before, :time_zone ]))
      redirect_to settings_path, notice: "Settings updated.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def ensure_reminder_emails_enabled
      return if Rails.configuration.x.reminder_emails_enabled

      head :not_found if params.dig(:user, :reminder_days_before)
    end
end
