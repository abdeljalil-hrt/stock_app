module Api
  module Chatgpt
    module V1
      class InventoryController < BaseController
        def show
          variants = Variant.left_joins(:stock_movements)
            .select("variants.id, variants.sku, variants.name, variants.phone_model, variants.design, variants.low_stock_threshold, COALESCE(SUM(stock_movements.quantity), 0) AS quantity_on_hand")
            .group("variants.id")
            .order(:sku)

          if params[:sku].present?
            variants = variants.where("LOWER(variants.sku) = ?", params[:sku].to_s.strip.downcase)
          end

          rows = variants.map do |variant|
            {
              sku: variant.sku,
              name: variant.name,
              phone_model: variant.phone_model,
              design: variant.design,
              quantity_on_hand: variant.quantity_on_hand.to_i,
              low_stock_threshold: variant.low_stock_threshold,
              low_stock: variant.quantity_on_hand.to_i <= variant.low_stock_threshold
            }
          end

          render json: {
            as_of: Time.current.iso8601,
            total_units: rows.sum { |row| row[:quantity_on_hand] },
            variant_count: rows.size,
            low_stock_count: rows.count { |row| row[:low_stock] },
            variants: rows
          }
        end
      end
    end
  end
end
