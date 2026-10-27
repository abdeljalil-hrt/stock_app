class AddBalanceChecks < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :active, :boolean, null: false, default: true
    add_column :accounts, :opening_balance_cents, :integer, null: false, default: 0

    create_table :balance_checks do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :expected_cents, null: false
      t.integer :real_cents, null: false
      t.integer :difference_cents, null: false
      t.date :checked_on, null: false
      t.text :note
      t.references :adjustment_transaction, foreign_key: { to_table: :transactions }
      t.timestamps
    end
    add_index :balance_checks, :checked_on
  end
end
