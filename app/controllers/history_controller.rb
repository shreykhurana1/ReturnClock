class HistoryController < ApplicationController
  def index
    purchases = Current.user.purchases
    purchases.expire_overdue!
    @purchases = purchases.in_history.includes(:store_policy).order(return_by: :desc, item_name: :asc, id: :desc)
  end
end
