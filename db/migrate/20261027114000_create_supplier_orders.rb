class CreateSupplierOrders < ActiveRecord::Migration[8.0]
  def up
    create_table :purchase_orders do |t|
      t.integer :number, null: false
      t.string :supplier, null: false
      t.string :status, null: false, default: "draft"
      t.date :ordered_on
      t.date :expected_on
      t.text :note
      t.timestamps
    end
    add_index :purchase_orders, :number, unique: true

    create_table :purchase_order_lines do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false
      t.timestamps
    end
    add_check_constraint :purchase_order_lines, "quantity > 0", name: "purchase_order_lines_quantity_positive"
    add_check_constraint :purchase_order_lines, "unit_price_cents >= 0", name: "purchase_order_lines_unit_price_nonnegative"

    create_table :purchase_order_costs do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :amount_cents, null: false
      t.date :paid_on
      t.references :account, foreign_key: true
      t.references :transaction, foreign_key: true
      t.timestamps
    end
    add_check_constraint :purchase_order_costs, "amount_cents >= 0", name: "purchase_order_costs_amount_nonnegative"
    add_reference :transactions, :purchase_order, foreign_key: true
    add_column :stock_movements, :unit_cost_cents, :integer

    create_table :purchase_receipts do |t|
      t.references :purchase_order_line, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.date :received_on, null: false
      t.timestamps
    end
    add_check_constraint :purchase_receipts, "quantity > 0", name: "purchase_receipts_quantity_positive"
  end

  def down
    remove_column :stock_movements, :unit_cost_cents
    remove_reference :transactions, :purchase_order_cost, if_exists: true
    remove_reference :transactions, :purchase_order
    drop_table :purchase_receipts
    drop_table :purchase_order_costs
    drop_table :purchase_order_lines
    drop_table :purchase_orders
    execute "DROP SEQUENCE IF EXISTS purchase_order_number_seq"
  end
end
