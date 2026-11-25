require "rails_helper"

RSpec.describe "Time zone and free purchases migration" do
  ZONE_MIGRATION = "20261124120000_add_time_zone_and_allow_free_purchases".freeze
  let(:connection) { ActiveRecord::Base.connection }

  def run(direction)
    require Rails.root.join("db/migrate/#{ZONE_MIGRATION}.rb")
    ActiveRecord::Migration.suppress_messages { AddTimeZoneAndAllowFreePurchases.new.migrate(direction) }
    [ User, Purchase ].each(&:reset_column_information)
  end

  def insert(sql)
    connection.select_value("#{sql} RETURNING id").to_i
  end

  def purchase_columns(user_id, policy_id, price)
    "(user_id, store_policy_id, item_name, price, purchase_date, return_by, status, created_at, updated_at) " \
      "VALUES (#{user_id}, #{policy_id}, 'Coat', #{price}, '2026-01-01', '2026-01-31', 'active', now(), now())"
  end

  around do |example|
    connection.transaction(requires_new: true) do
      run(:down)
      example.run
      raise ActiveRecord::Rollback
    end
  ensure
    [ User, Purchase ].each(&:reset_column_information)
  end

  it "gives existing users the UTC time zone" do
    digest = connection.quote(BCrypt::Password.create("Password1!", cost: BCrypt::Engine::MIN_COST))
    insert("INSERT INTO users (email_address, password_digest, created_at, updated_at) VALUES ('old@example.com', #{digest}, now(), now())")

    run(:up)

    expect(connection.select_value("SELECT time_zone FROM users WHERE email_address = 'old@example.com'")).to eq("UTC")
    expect(User.columns_hash.fetch("time_zone").null).to be(false)
  end

  it "keeps existing purchases and allows a price of 0 but not a negative one" do
    digest = connection.quote(BCrypt::Password.create("Password1!", cost: BCrypt::Engine::MIN_COST))
    user_id = insert("INSERT INTO users (email_address, password_digest, created_at, updated_at) VALUES ('old@example.com', #{digest}, now(), now())")
    policy_id = insert("INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at) VALUES (#{user_id}, 'Zara', 30, now(), now())")
    insert("INSERT INTO purchases #{purchase_columns(user_id, policy_id, 25)}")

    run(:up)

    expect(connection.select_value("SELECT price FROM purchases").to_d).to eq(25)
    expect { connection.transaction(requires_new: true) { insert("INSERT INTO purchases #{purchase_columns(user_id, policy_id, 0)}") } }.not_to raise_error
    expect { connection.transaction(requires_new: true) { insert("INSERT INTO purchases #{purchase_columns(user_id, policy_id, -1)}") } }
      .to raise_error(ActiveRecord::StatementInvalid, /purchases_price_non_negative/)
  end

  it "rolls back to the positive-price rule when no purchase is free" do
    run(:up)
    run(:down)

    expect(User.column_names).not_to include("time_zone")
    expect(connection.check_constraints(:purchases).map(&:name)).to contain_exactly("purchases_price_positive")
  end
end
