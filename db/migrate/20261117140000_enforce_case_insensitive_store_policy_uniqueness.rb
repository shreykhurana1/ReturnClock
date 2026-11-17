class EnforceCaseInsensitiveStorePolicyUniqueness < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_store_policies_on_user_lower_store_and_window"
  PREVIOUS_INDEX_NAME = "index_store_policies_on_user_store_and_window"

  def up
    # Keep the preflight and index creation atomic with respect to policy writes.
    execute "LOCK TABLE store_policies IN SHARE ROW EXCLUSIVE MODE"
    conflicts = select_all(<<~SQL).to_a
      SELECT user_id, lower(store_name) AS store_name, window_days,
             array_agg(id ORDER BY id) AS policy_ids
      FROM store_policies
      GROUP BY user_id, lower(store_name), window_days
      HAVING count(*) > 1
      ORDER BY user_id, lower(store_name), window_days
    SQL
    if conflicts.any?
      raise ActiveRecord::MigrationError,
        "Case-insensitive store policy conflicts: #{conflicts.inspect}. " \
        "No policies or purchases were changed. Review these IDs and resolve conflicts manually before retrying."
    end

    add_index :store_policies, "user_id, lower(store_name), window_days", unique: true, name: INDEX_NAME
    remove_index :store_policies, name: PREVIOUS_INDEX_NAME
  end

  def down
    execute "LOCK TABLE store_policies IN SHARE ROW EXCLUSIVE MODE"
    # Stop a full rollback before the earlier migration drops preferences and outcome dates.
    conflicts = select_all(<<~SQL).to_a
      SELECT user_id, store_name, array_agg(id ORDER BY id) AS policy_ids
      FROM store_policies
      GROUP BY user_id, store_name
      HAVING count(*) > 1
      ORDER BY user_id, store_name
    SQL
    if conflicts.any?
      raise ActiveRecord::IrreversibleMigration,
        "Cannot roll back store policy support while stores have multiple windows: #{conflicts.inspect}. " \
        "No records or indexes were changed. Back up and plan manual remediation before rolling back."
    end

    add_index :store_policies, [ :user_id, :store_name, :window_days ], unique: true, name: PREVIOUS_INDEX_NAME
    remove_index :store_policies, name: INDEX_NAME
  end
end
