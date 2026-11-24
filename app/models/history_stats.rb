class HistoryStats
  def self.for(user)
    history = user.purchases
      .where(status: %w[keeping refunded])
      .or(user.purchases.where(status: "active", return_by: ...Date.current))

    {
      total: history.count,
      refunded: history.where(status: "refunded").count,
      keeping: history.where(status: "keeping").count,
      expired: history.where(status: "active", return_by: ...Date.current).count
    }
  end
end
