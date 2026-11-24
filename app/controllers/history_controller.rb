class HistoryController < ApplicationController
  layout "application"

  HISTORY_PER_PAGE = 6
  HISTORY_FILTERS = %w[all refunded keeping expired].freeze

  def index
    history_scope = Current.user.purchases
      .where(status: %w[keeping refunded])
      .or(Current.user.purchases.where(status: "active", return_by: ...Date.current))

    @stats = HistoryStats.for(Current.user)
    @filter = HISTORY_FILTERS.include?(params[:filter]) ? params[:filter] : "all"
    filtered_scope = filtered_history(history_scope)
    @filtered_count = filtered_scope.count
    @total_pages = [ (@filtered_count / HISTORY_PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)

    @purchases = filtered_scope.includes(:store_policy)
      .order(return_by: :desc, id: :desc)
      .offset((@page - 1) * HISTORY_PER_PAGE)
      .limit(HISTORY_PER_PAGE)
  end

  private

  def filtered_history(history_scope)
    case @filter
    when "refunded" then history_scope.where(status: "refunded")
    when "keeping" then history_scope.where(status: "keeping")
    when "expired" then history_scope.where(status: "active", return_by: ...Date.current)
    else history_scope
    end
  end
end
