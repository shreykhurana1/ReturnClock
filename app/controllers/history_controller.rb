class HistoryController < ApplicationController
  def index
    purchases = Current.user.purchases
    @purchases = purchases.where(status: %w[keeping refunded])
      .or(purchases.where(status: "active", return_by: ...Date.current))
      .includes(:store_policy).order(return_by: :desc, id: :desc)
  end
end
