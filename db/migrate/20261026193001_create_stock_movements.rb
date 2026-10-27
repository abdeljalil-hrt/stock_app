class CreateStockMovements < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_movements do |t|
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.string :kind, null: false
      t.string :reference
      t.text :note
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :stock_movements, %i[variant_id kind reference]
  end
end
