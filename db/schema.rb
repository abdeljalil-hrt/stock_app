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

ActiveRecord::Schema[8.0].define(version: 2026_10_27_123000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.integer "opening_balance_cents", default: 0, null: false
    t.index ["name"], name: "index_accounts_on_name", unique: true
  end

  create_table "balance_checks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "expected_cents", null: false
    t.integer "real_cents", null: false
    t.integer "difference_cents", null: false
    t.date "checked_on", null: false
    t.text "note"
    t.bigint "adjustment_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_balance_checks_on_account_id"
    t.index ["adjustment_transaction_id"], name: "index_balance_checks_on_adjustment_transaction_id"
    t.index ["checked_on"], name: "index_balance_checks_on_checked_on"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", default: "expense", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "category_keywords", force: :cascade do |t|
    t.string "keyword", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_keywords_on_category_id"
    t.index ["keyword"], name: "index_category_keywords_on_keyword", unique: true
  end

  create_table "month_closures", force: :cascade do |t|
    t.date "month", null: false
    t.integer "net_profit_cents", null: false
    t.integer "giving_cents", null: false
    t.datetime "closed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["month"], name: "index_month_closures_on_month", unique: true
  end

  create_table "pots", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_pots_on_name", unique: true
  end

  create_table "purchase_order_costs", force: :cascade do |t|
    t.bigint "purchase_order_id", null: false
    t.string "kind", null: false
    t.integer "amount_cents", null: false
    t.date "paid_on"
    t.bigint "account_id"
    t.bigint "transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_purchase_order_costs_on_account_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_costs_on_purchase_order_id"
    t.index ["transaction_id"], name: "index_purchase_order_costs_on_transaction_id"
    t.check_constraint "amount_cents >= 0", name: "purchase_order_costs_amount_nonnegative"
  end

  create_table "purchase_order_lines", force: :cascade do |t|
    t.bigint "purchase_order_id", null: false
    t.bigint "variant_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_order_id"], name: "index_purchase_order_lines_on_purchase_order_id"
    t.index ["variant_id"], name: "index_purchase_order_lines_on_variant_id"
    t.check_constraint "quantity > 0", name: "purchase_order_lines_quantity_positive"
    t.check_constraint "unit_price_cents >= 0", name: "purchase_order_lines_unit_price_nonnegative"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.integer "number", null: false
    t.string "supplier", null: false
    t.string "status", default: "draft", null: false
    t.date "ordered_on"
    t.date "expected_on"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_purchase_orders_on_number", unique: true
  end

  create_table "purchase_receipts", force: :cascade do |t|
    t.bigint "purchase_order_line_id", null: false
    t.integer "quantity", null: false
    t.date "received_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_order_line_id"], name: "index_purchase_receipts_on_purchase_order_line_id"
    t.check_constraint "quantity > 0", name: "purchase_receipts_quantity_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "variant_id", null: false
    t.integer "quantity", null: false
    t.string "kind", null: false
    t.string "reference"
    t.text "note"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "unit_cost_cents"
    t.index ["kind", "created_at"], name: "index_stock_movements_on_kind_and_created_at"
    t.index ["variant_id", "created_at"], name: "index_stock_movements_on_variant_id_and_created_at"
    t.index ["variant_id", "kind", "reference"], name: "index_stock_movements_on_variant_id_and_kind_and_reference"
    t.index ["variant_id"], name: "index_stock_movements_on_variant_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.date "date", null: false
    t.integer "amount_cents", null: false
    t.string "kind", default: "expense", null: false
    t.string "purchase_order_reference"
    t.text "note"
    t.bigint "category_id", null: false
    t.bigint "account_id", null: false
    t.bigint "pot_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "purchase_order_id"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date", "kind"], name: "index_transactions_on_date_and_kind"
    t.index ["pot_id"], name: "index_transactions_on_pot_id"
    t.index ["purchase_order_id"], name: "index_transactions_on_purchase_order_id"
    t.check_constraint "amount_cents > 0", name: "transactions_amount_cents_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "owner", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.string "sku", null: false
    t.string "name", null: false
    t.string "design", null: false
    t.string "phone_model", null: false
    t.integer "low_stock_threshold", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cost_price", precision: 10, scale: 2
    t.index ["sku"], name: "index_variants_on_sku", unique: true
  end

  add_foreign_key "balance_checks", "accounts"
  add_foreign_key "balance_checks", "transactions", column: "adjustment_transaction_id"
  add_foreign_key "category_keywords", "categories"
  add_foreign_key "purchase_order_costs", "accounts"
  add_foreign_key "purchase_order_costs", "purchase_orders"
  add_foreign_key "purchase_order_costs", "transactions"
  add_foreign_key "purchase_order_lines", "purchase_orders"
  add_foreign_key "purchase_order_lines", "variants"
  add_foreign_key "purchase_receipts", "purchase_order_lines"
  add_foreign_key "sessions", "users"
  add_foreign_key "stock_movements", "variants"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "pots"
  add_foreign_key "transactions", "purchase_orders"
end
