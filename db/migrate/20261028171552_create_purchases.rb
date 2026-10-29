class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :store_policy, null: false, foreign_key: true

      t.string :item_name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.date :purchase_date, null: false
      t.date :return_by, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_check_constraint :purchases,
                         "price > 0",
                         name: "purchases_price_positive"
  end
end
