class CreateVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :variants do |t|
      t.string :sku, null: false
      t.string :name, null: false
      t.string :design, null: false
      t.string :phone_model, null: false
      t.integer :low_stock_threshold, null: false, default: 5
      t.timestamps
    end

    add_index :variants, :sku, unique: true
  end
end
