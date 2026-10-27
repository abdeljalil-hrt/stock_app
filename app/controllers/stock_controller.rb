class StockController < ApplicationController
  def index
    @designs = Variant.distinct.order(:design).pluck(:design)
    @search = params[:q].to_s.strip
    @design = @designs.include?(params[:design]) ? params[:design] : nil

    variants = Variant.all
    variants = variants.where(design: @design) if @design
    if @search.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"
      variants = variants.where("variants.sku ILIKE :pattern OR variants.name ILIKE :pattern OR variants.phone_model ILIKE :pattern", pattern: pattern)
    end
    variants = variants
      .left_joins(:stock_movements)
      .select("variants.*, COALESCE(SUM(stock_movements.quantity), 0) AS current_stock")
      .group("variants.id")
      .order(:sku)

    case params[:status]
    when "low"
      variants = variants.having("COALESCE(SUM(stock_movements.quantity), 0) > 0 AND COALESCE(SUM(stock_movements.quantity), 0) <= variants.low_stock_threshold")
    when "out"
      variants = variants.having("COALESCE(SUM(stock_movements.quantity), 0) <= 0")
    end

    @variants_by_design = variants.to_a.group_by(&:design)
    @status = params[:status]
  end
end
