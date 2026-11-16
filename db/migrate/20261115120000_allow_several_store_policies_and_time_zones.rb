class AllowSeveralStorePoliciesAndTimeZones < ActiveRecord::Migration[8.1]
  def change
    remove_index :store_policies, name: "index_store_policies_on_user_id_and_lower_store_name", column: "user_id, LOWER(store_name)", unique: true
    add_index :store_policies, "user_id, LOWER(store_name), window_days", unique: true, name: "index_store_policies_on_user_store_and_window"

    add_column :users, :time_zone, :string, null: false, default: "UTC"
  end
end
