class AddCostPriceAndDashboardIndexes < ActiveRecord::Migration[8.0]
  def change
    add_column :variants, :cost_price, :decimal, precision: 10, scale: 2
    add_index :stock_movements, %i[kind created_at]
    add_index :stock_movements, %i[variant_id created_at]
  end
end
