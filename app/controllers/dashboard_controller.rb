class DashboardController < ApplicationController
  def index
    purchases = Current.user.purchases
    purchases.expire_overdue!
    @purchases = purchases.on_dashboard.includes(:store_policy).order(:return_by, :id)
  end
end
