class CreateFinanceExpenseRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "expense"
      t.timestamps
    end
    add_index :categories, :name, unique: true

    create_table :accounts do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :accounts, :name, unique: true

    create_table :pots do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :pots, :name, unique: true

    create_table :transactions do |t|
      t.date :date, null: false
      t.integer :amount_cents, null: false
      t.string :kind, null: false, default: "expense"
      t.string :purchase_order_reference
      t.text :note
      t.references :category, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :pot, foreign_key: true
      t.timestamps
    end
    add_check_constraint :transactions, "amount_cents > 0", name: "transactions_amount_cents_positive"
    add_index :transactions, [:date, :kind]

    create_table :category_keywords do |t|
      t.string :keyword, null: false
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :category_keywords, :keyword, unique: true
  end
end
