class DashboardController < ApplicationController
  # Modal saves reuse this full-page response, including its header and tracked assets.
  layout "application"

  DASHBOARD_PER_PAGE = 6
  DASHBOARD_FILTERS = { "all" => nil, "week" => 7, "two_weeks" => 14, "month" => 30 }.freeze

  def index
    purchases = Current.user.purchases
    scope = purchases.where(status: "active", return_by: Date.current..)
      .or(purchases.where(status: %w[returning shipped_back refund_pending]))

    @stats = DashboardStats.for(Current.user)
    @filter = DASHBOARD_FILTERS.key?(params[:filter]) ? params[:filter] : "all"
    @filter_days = DASHBOARD_FILTERS[@filter]
    filtered_scope = @filter_days ? scope.where(return_by: Date.current..(Date.current + @filter_days)) : scope
    @filtered_count = filtered_scope.count
    @total_pages = [ (@filtered_count / DASHBOARD_PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @purchases = filtered_scope.includes(:store_policy).order(:return_by, :id)
      .offset((@page - 1) * DASHBOARD_PER_PAGE)
      .limit(DASHBOARD_PER_PAGE)
  end
end
