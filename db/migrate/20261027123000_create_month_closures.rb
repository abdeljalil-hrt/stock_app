class CreateMonthClosures < ActiveRecord::Migration[8.0]
  def change
    create_table :month_closures do |t|
      t.date :month, null: false
      t.integer :net_profit_cents, null: false
      t.integer :giving_cents, null: false
      t.datetime :closed_at, null: false
      t.timestamps
    end
    add_index :month_closures, :month, unique: true
  end
end
