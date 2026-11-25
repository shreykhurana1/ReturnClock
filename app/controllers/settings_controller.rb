class SettingsController < ApplicationController
  def show
  end

  def update
    if Current.user.update(params.expect(user: [ :reminder_days_before, :time_zone ]))
      redirect_to settings_path, notice: "Settings updated.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end
end
