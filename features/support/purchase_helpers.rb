module PurchaseHelpers
  # Purchase cards and store policy cards both render as .purchase-card with the name in an h2.
  def card_named(name)
    find(".purchase-card h2", exact_text: name).ancestor(".purchase-card")
  end

  # Turns a status label such as "Shipped back" into its stored value.
  def status_value(label)
    label.downcase.tr(" ", "_")
  end

  def create_purchases(user, table)
    table.hashes.each do |row|
      user.purchases.create!(
        item_name: row.fetch("item"),
        store_name: row["store"].presence,
        price: row["price"].presence,
        purchase_date: row["purchase_date"].presence,
        return_by: row.fetch("return_by"),
        status: status_value(row["status"].presence || "Active")
      )
    end
  end
end

World(PurchaseHelpers)
