require "rails_helper"

# Runs the two schema migrations against rows saved the way production data looks today.
# Postgres DDL is transactional, so the example's transaction restores the schema afterwards.
RSpec.describe "Store policy and reminder migrations" do
  MIGRATIONS = {
    index: [ "20261117120000_allow_several_store_policies_per_store", "AllowSeveralStorePoliciesPerStore" ],
    columns: [ "20261117130000_add_reminder_and_outcome_columns", "AddReminderAndOutcomeColumns" ]
  }.freeze

  let(:connection) { ActiveRecord::Base.connection }

  def migration(name)
    file, klass = MIGRATIONS.fetch(name)
    require Rails.root.join("db/migrate/#{file}.rb")
    klass.constantize.new
  end

  def run(name, direction)
    ActiveRecord::Migration.suppress_messages { migration(name).migrate(direction) }
  end

  def reset_columns
    [ User, Purchase, StorePolicy ].each(&:reset_column_information)
  end

  def insert(sql)
    connection.select_value("#{sql} RETURNING id").to_i
  end

  around do |example|
    run(:columns, :down)
    run(:index, :down)
    reset_columns
    example.run
  ensure
    run(:index, :up) unless connection.index_exists?(:store_policies, [ :user_id, :store_name, :window_days ], unique: true)
    run(:columns, :up) unless connection.column_exists?(:users, :reminder_days_before)
    reset_columns
  end

  let!(:user_id) do
    insert("INSERT INTO users (email_address, password_digest, created_at, updated_at) VALUES ('old@example.com', 'x', now(), now())")
  end
  let!(:policy_id) do
    insert("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{user_id}, 'Zara', 30, now(), now())")
  end
  # Under the old index "zara" is a different name from "Zara", so both rows can already exist.
  let!(:lowercase_policy_id) do
    insert("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{user_id}, 'zara', 30, now(), now())")
  end

  def insert_purchase(status, item)
    insert(<<~SQL)
      INSERT INTO purchases (user_id, store_policy_id, item_name, price, purchase_date, return_by, status, created_at, updated_at)
      VALUES (#{user_id}, #{policy_id}, '#{item}', 20, '2026-01-01', '2026-01-31', '#{status}', now(), now())
    SQL
  end

  it "keeps every existing row, status and policy link, even for overdue purchases" do
    overdue = insert_purchase("active", "Overdue")
    refunded = insert_purchase("refunded", "Refunded")

    run(:index, :up)
    run(:columns, :up)
    reset_columns

    expect(StorePolicy.pluck(:store_name)).to contain_exactly("Zara", "zara")
    expect(Purchase.find(overdue)).to have_attributes(status: "active", store_policy_id: policy_id, item_name: "Overdue")
    expect(Purchase.find(refunded)).to have_attributes(status: "refunded", store_policy_id: policy_id)
  end

  it "defaults existing users to a 2-day alert and leaves the new purchase dates empty" do
    purchase_id = insert_purchase("shipped_back", "Boots")

    run(:index, :up)
    run(:columns, :up)
    reset_columns

    expect(User.find(user_id).reminder_days_before).to eq(2)
    expect(Purchase.find(purchase_id)).to have_attributes(returned_at: nil, refunded_at: nil, reminded_at: nil)
  end

  it "allows a second window for the same store but still rejects an exact duplicate" do
    run(:index, :up)
    reset_columns

    expect do
      insert("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{user_id}, 'Zara', 60, now(), now())")
    end.not_to raise_error

    expect do
      connection.transaction(requires_new: true) do
        connection.execute("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{user_id}, 'Zara', 60, now(), now())")
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rolls back cleanly while each store still has one window" do
    run(:index, :up)
    run(:columns, :up)
    run(:columns, :down)
    run(:index, :down)

    expect(connection.index_exists?(:store_policies, [ :user_id, :store_name ], unique: true)).to be(true)
    expect(connection.column_exists?(:users, :reminder_days_before)).to be(false)
  end
end
