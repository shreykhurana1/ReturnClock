class AllowSeveralStorePoliciesPerStore < ActiveRecord::Migration[8.1]
  # Only loosens the old (user, store) uniqueness, so no existing row can violate the new index.
  def change
    remove_index :store_policies, [ :user_id, :store_name ], unique: true
    add_index :store_policies, [ :user_id, :store_name, :window_days ], unique: true, name: "index_store_policies_on_user_store_and_window"
  end
end
