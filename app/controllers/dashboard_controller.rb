class DashboardController < ApplicationController
  # Modal saves reuse this full-page response, including its header and tracked assets.
  layout "application"

  def index
    purchases = Current.user.purchases
    @purchases = purchases.where(status: "active", return_by: Date.current..)
      .or(purchases.where(status: %w[returning shipped_back refund_pending]))
      .includes(:store_policy).order(:return_by, :id)
  end
end
