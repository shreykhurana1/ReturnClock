# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_171552) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "store_policy_id", null: false
    t.string "item_name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.date "purchase_date", null: false
    t.date "return_by", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_policy_id"], name: "index_purchases_on_store_policy_id"
    t.index ["user_id"], name: "index_purchases_on_user_id"
    t.check_constraint "price > 0::numeric", name: "purchases_price_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "store_policies", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "store_name", null: false
    t.integer "window_days", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "store_name"], name: "index_store_policies_on_user_id_and_store_name", unique: true
    t.index ["user_id"], name: "index_store_policies_on_user_id"
    t.check_constraint "window_days > 0", name: "store_policies_window_days_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "purchases", "store_policies"
  add_foreign_key "purchases", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "store_policies", "users"
end
