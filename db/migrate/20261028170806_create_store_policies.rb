class CreateStorePolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :store_policies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :store_name, null: false
      t.integer :window_days, null: false

      t.timestamps
    end

    add_index :store_policies,
              [:user_id, :store_name],
              unique: true

    add_check_constraint :store_policies,
                         "window_days > 0",
                         name: "store_policies_window_days_positive"
  end
end
