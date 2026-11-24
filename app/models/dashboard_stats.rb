class DashboardStats
  def self.for(user)
    purchases = user.purchases
    actionable = purchases.where(status: "active", return_by: Date.current..)
      .or(purchases.where(status: %w[returning shipped_back refund_pending]))

    {
      total: actionable.count,
      due_week: actionable.where(return_by: Date.current..(Date.current + 7)).count,
      money_at_risk: actionable.where(status: Purchase::OPEN_STATUSES).sum(:price),
      savings: purchases.where(status: "refunded").sum(:price)
    }
  end
end
