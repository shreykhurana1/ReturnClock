class AddFlexiblePurchaseDetails < ActiveRecord::Migration[8.1]
  def change
    change_column_null :purchases, :store_policy_id, true
    change_column_null :purchases, :price, true
    change_column_null :purchases, :purchase_date, true

    add_column :purchases, :store_name, :string
    add_column :purchases, :return_window_days, :integer
    add_column :purchases, :returned_at, :date
    add_column :purchases, :refunded_at, :date
    add_column :purchases, :reminded_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE purchases
          SET store_name = store_policies.store_name,
              return_window_days = purchases.return_by - purchases.purchase_date
          FROM store_policies
          WHERE store_policies.id = purchases.store_policy_id
        SQL
        execute <<~SQL
          UPDATE purchases SET status = 'expired'
          WHERE status IN ('active', 'returning') AND return_by < CURRENT_DATE
        SQL
      end
    end

    remove_index :store_policies, [ :user_id, :store_name ], unique: true
    add_index :store_policies, "user_id, LOWER(store_name)", unique: true, name: "index_store_policies_on_user_id_and_lower_store_name"

    add_column :users, :reminder_days_before, :integer, null: false, default: 2
  end
end
