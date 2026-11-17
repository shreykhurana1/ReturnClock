require "rails_helper"

# Every DDL change and seeded record is rolled back, including when a preflight refuses to proceed.
RSpec.describe "Store policy and reminder migrations" do
  MIGRATIONS = {
    index: [ "20261117120000_allow_several_store_policies_per_store", "AllowSeveralStorePoliciesPerStore" ],
    columns: [ "20261117130000_add_reminder_and_outcome_columns", "AddReminderAndOutcomeColumns" ],
    uniqueness: [ "20261117140000_enforce_case_insensitive_store_policy_uniqueness", "EnforceCaseInsensitiveStorePolicyUniqueness" ]
  }.freeze
  UNIQUE_INDEX = "index_store_policies_on_user_lower_store_and_window"
  PREVIOUS_INDEX = "index_store_policies_on_user_store_and_window"

  let(:connection) { ActiveRecord::Base.connection }

  def run(name, direction)
    file, klass = MIGRATIONS.fetch(name)
    require Rails.root.join("db/migrate/#{file}.rb")
    ActiveRecord::Migration.suppress_messages { klass.constantize.new.migrate(direction) }
  end

  def reset_columns
    [ User, Purchase, StorePolicy ].each(&:reset_column_information)
  end

  def migrate_up
    run(:index, :up)
    run(:columns, :up)
    run(:uniqueness, :up)
    reset_columns
  end

  def insert(sql)
    connection.select_value("#{sql} RETURNING id").to_i
  end

  def insert_user(email)
    digest = connection.quote(BCrypt::Password.create("Password1!", cost: BCrypt::Engine::MIN_COST))
    insert("INSERT INTO users (email_address, password_digest, created_at, updated_at) VALUES (#{connection.quote(email)}, #{digest}, now(), now())")
  end

  def insert_policy(name, days, owner: user_id)
    insert("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{owner}, #{connection.quote(name)}, #{days}, now(), now())")
  end

  def insert_purchase(status, policy: policy_id)
    insert(<<~SQL)
      INSERT INTO purchases (user_id, store_policy_id, item_name, price, purchase_date, return_by, status, created_at, updated_at)
      VALUES (#{user_id}, #{policy}, 'Old purchase', 20, '2026-01-01', '2026-01-31', '#{status}', now(), now())
    SQL
  end

  around do |example|
    connection.transaction(requires_new: true) do
      run(:uniqueness, :down)
      run(:columns, :down)
      run(:index, :down)
      reset_columns
      example.run
      raise ActiveRecord::Rollback
    end
  ensure
    reset_columns
  end

  let!(:user_id) { insert_user("old@example.com") }
  let!(:policy_id) { insert_policy("Zara", 30) }

  it "preserves populated purchases, all six statuses, associations and saved deadlines" do
    ids = Purchase::STATUSES.map { |status| insert_purchase(status) }
    # Simulate an earlier policy edit: the saved 30-day purchase deadlines must stay unchanged.
    connection.execute("UPDATE store_policies SET window_days = 60 WHERE id = #{policy_id}")
    before = connection.select_all("SELECT id, user_id, store_policy_id, status, return_by FROM purchases ORDER BY id").to_a
    migrate_up
    expect(connection.select_all("SELECT id, user_id, store_policy_id, status, return_by FROM purchases ORDER BY id").to_a).to eq(before)
    expect(Purchase.where(id: ids).all?(&:valid?)).to be(true)
    expect(StorePolicy.find(policy_id)).to be_valid
  end

  it "defaults existing users to two days and does not invent historical outcome dates" do
    id = insert_purchase("shipped_back")
    migrate_up
    expect(User.find(user_id).reminder_days_before).to eq(2)
    expect(Purchase.find(id)).to have_attributes(returned_at: nil, refunded_at: nil, reminded_at: nil)
  end

  it "accepts legacy case variants with different windows and identical policies in other accounts" do
    second = insert_policy("zara", 60)
    other = insert_policy("ZARA", 30, owner: insert_user("other@example.com"))
    migrate_up
    expect(StorePolicy.where(id: [ policy_id, second, other ]).all?(&:valid?)).to be(true)
  end

  it "reports conflicting legacy IDs before changing indexes or records" do
    conflict = insert_policy("ZARA", 30)
    insert_purchase("refunded", policy: conflict)
    run(:index, :up)
    run(:columns, :up)
    policies = connection.select_all("SELECT * FROM store_policies ORDER BY id").to_a
    purchases = connection.select_all("SELECT * FROM purchases ORDER BY id").to_a
    expect { run(:uniqueness, :up) }.to raise_error(ActiveRecord::MigrationError) { |error|
      expect(error.message).to include("Case-insensitive store policy conflicts", "policy_ids", policy_id.to_s, conflict.to_s, "No policies or purchases were changed")
    }
    expect(connection.index_name_exists?(:store_policies, PREVIOUS_INDEX)).to be(true)
    expect(connection.index_name_exists?(:store_policies, UNIQUE_INDEX)).to be(false)
    expect(connection.select_all("SELECT * FROM store_policies ORDER BY id").to_a).to eq(policies)
    expect(connection.select_all("SELECT * FROM purchases ORDER BY id").to_a).to eq(purchases)
  end

  [ "Zara", "ZARA" ].each do |name|
    it "rejects a duplicate #{name}/30 at the database level without Rails validation" do
      migrate_up
      expect do
        connection.transaction(requires_new: true) { insert_policy(name, 30) }
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "permits multiple windows and account-specific policies at the database level" do
    migrate_up
    second = insert_policy("ZARA", 60)
    other = insert_policy("ZARA", 30, owner: insert_user("other@example.com"))
    expect(StorePolicy.where(id: [ policy_id, second, other ]).count).to eq(3)
  end

  it "rolls back to the original schema when each store has only one window" do
    insert_purchase("active")
    migrate_up
    run(:uniqueness, :down)
    run(:columns, :down)
    run(:index, :down)
    expect(connection.index_exists?(:store_policies, [ :user_id, :store_name ], unique: true)).to be(true)
    expect(connection.column_exists?(:users, :reminder_days_before)).to be(false)
    expect(connection.select_value("SELECT store_policy_id FROM purchases").to_i).to eq(policy_id)
  end

  it "refuses unsafe rollback before removing indexes, preferences or outcome dates" do
    id = insert_purchase("refunded")
    migrate_up
    insert_policy("Zara", 60)
    User.find(user_id).update!(reminder_days_before: 7)
    Purchase.find(id).update_columns(returned_at: Date.new(2026, 1, 10), refunded_at: Date.new(2026, 1, 15))
    expect { run(:uniqueness, :down) }.to raise_error(ActiveRecord::IrreversibleMigration, /multiple windows/)
    expect(connection.index_name_exists?(:store_policies, UNIQUE_INDEX)).to be(true)
    expect(User.find(user_id).reminder_days_before).to eq(7)
    expect(Purchase.find(id)).to have_attributes(store_policy_id: policy_id, return_by: Date.new(2026, 1, 31),
      returned_at: Date.new(2026, 1, 10), refunded_at: Date.new(2026, 1, 15))
  end
end
