class AddTimeZoneAndAllowFreePurchases < ActiveRecord::Migration[8.1]
  # Each user gets a time zone for "today" and "days left"; a blank purchase price is stored as 0, so 0 is now allowed.
  # Rolling back fails while any purchase has price 0, because the old price > 0 rule cannot hold for it.
  def change
    add_column :users, :time_zone, :string, null: false, default: "UTC"

    remove_check_constraint :purchases, "price > 0", name: "purchases_price_positive"
    add_check_constraint :purchases, "price >= 0", name: "purchases_price_non_negative"
  end
end
