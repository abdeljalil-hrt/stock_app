class DashboardStats
  PERIOD_DAYS = [7, 30, 90].freeze
  ReorderItem = Struct.new(
    :variant, :shipped, :average_daily, :days_cover, :suggested_order,
    keyword_init: true
  )

  attr_reader :days, :start_at, :now, :stock_rows, :kpis, :shipments_by_day,
    :returns_by_week, :stock_by_model, :top_sellers, :reorder_items,
    :dead_stock, :return_rates_by_variant, :recent_activity, :stock_matrix,
    :designs, :strap_stock

  def initialize(period: 30, now: Time.current)
    @days = PERIOD_DAYS.include?(period.to_i) ? period.to_i : 30
    @now = now
    @start_at = days.days.ago(now).beginning_of_day

    load_stock
    load_kpis
    load_period_aggregates
    load_reorder
    load_insights
    load_recent_activity
  end

  def self.reorder_metrics(stock:, shipped:, window_days: 30, target_days: 30)
    average_daily = shipped.to_f / window_days
    days_cover = average_daily.positive? ? stock.to_f / average_daily : nil
    suggested_order = [(average_daily * target_days).ceil - stock, 0].max
    [average_daily, days_cover, suggested_order]
  end

  private

  def load_stock
    @stock_rows = Variant
      .left_joins(:stock_movements)
      .select("variants.*, COALESCE(SUM(stock_movements.quantity), 0) AS current_stock")
      .group("variants.id")
      .order(:sku)
      .to_a
    @stock_by_id = @stock_rows.index_by(&:id)
    @stock_matrix = @stock_rows.reject { |variant| variant.design == "STRAP" }
      .index_by { |variant| [variant.phone_model, variant.design] }
    @designs = @stock_rows.map(&:design).uniq.reject { |design| design == "STRAP" }.sort
    @strap_stock = @stock_rows.select { |variant| variant.design == "STRAP" }.sum(&:current_stock)
    @stock_by_model = @stock_rows.reject { |variant| variant.design == "STRAP" }
      .group_by(&:phone_model).transform_values { |variants| variants.sum(&:current_stock) }
      .sort.to_h
  end

  def load_kpis
    movement_counts = StockMovement.where(created_at: start_at..now)
      .group(:kind).count
    stock_total = stock_rows.sum(&:current_stock)
    low_count = stock_rows.count { |variant| variant.current_stock.positive? && variant.current_stock <= variant.low_stock_threshold }
    out_count = stock_rows.count { |variant| variant.current_stock <= 0 }
    shipped = movement_counts.fetch("ship", 0)
    returned = StockMovement::RETURN_KINDS.sum { |kind| movement_counts.fetch(kind, 0) }
    @kpis = {
      units_in_stock: stock_total,
      units_by_design: stock_rows.group_by(&:design).transform_values { |variants| variants.sum(&:current_stock) },
      shipped: shipped,
      shipped_today: StockMovement.where(kind: "ship", created_at: now.beginning_of_day..now).count,
      returns: returned,
      return_rate: shipped.zero? ? "-" : (returned * 100.0 / shipped).round(1),
      low_stock: low_count,
      out_of_stock: out_count,
      damaged: movement_counts.fetch("return_damaged", 0),
      net_adjustments: StockMovement.where(kind: "adjustment", created_at: start_at..now).sum(:quantity)
    }
  end

  def load_period_aggregates
    period_movements = StockMovement.where(created_at: start_at..now)
    @shipments_by_day = period_movements.where(kind: "ship")
      .group_by_day(:created_at, range: start_at.to_date..now.to_date, series: true)
      .count
    weekly_counts = period_movements.where(kind: ["ship", *StockMovement::RETURN_KINDS])
      .group_by_week(:created_at, range: start_at.to_date..now.to_date, series: true)
      .group(:kind).count
    week_dates = period_movements.where(kind: ["ship", *StockMovement::RETURN_KINDS])
      .group_by_week(:created_at, range: start_at.to_date..now.to_date, series: true)
      .count.keys
    @returns_by_week = week_dates.to_h do |week|
      shipped = weekly_counts.fetch([week, "ship"], 0)
      returned = StockMovement::RETURN_KINDS.sum { |kind| weekly_counts.fetch([week, kind], 0) }
      [week, shipped.zero? ? 0 : (returned * 100.0 / shipped).round(1)]
    end

    @top_sellers = period_movements.where(kind: "ship")
      .group(:variant_id).order(Arel.sql("COUNT(*) DESC")).limit(10).count
      .filter_map { |variant_id, count| [@stock_by_id[variant_id], count] }

    @return_rates_by_variant = period_movements.where(kind: ["ship", *StockMovement::RETURN_KINDS])
      .group(:variant_id, :kind).count
      .group_by { |(variant_id, _kind), _count| variant_id }
      .filter_map do |variant_id, rows|
        counts = rows.to_h { |(_id, kind), count| [kind, count] }
        shipped = counts.fetch("ship", 0)
        next if shipped < 5

        returned = StockMovement::RETURN_KINDS.sum { |kind| counts.fetch(kind, 0) }
        [@stock_by_id[variant_id], returned, (returned * 100.0 / shipped).round(1)]
      end
      .sort_by { |_variant, _returned, rate| -rate }
      .first(5)
  end

  def load_reorder
    window_start = 30.days.ago(now).beginning_of_day
    shipment_counts = StockMovement.where(kind: "ship", created_at: window_start..now)
      .group(:variant_id).count

    @reorder_items = shipment_counts.filter_map do |variant_id, shipped|
      variant = @stock_by_id[variant_id]
      next unless variant

      average, cover, suggestion = self.class.reorder_metrics(stock: variant.current_stock, shipped: shipped)
      ReorderItem.new(
        variant: variant,
        shipped: shipped,
        average_daily: average,
        days_cover: cover,
        suggested_order: suggestion
      )
    end.sort_by { |item| [item.days_cover || Float::INFINITY, item.variant.sku] }.first(15)
  end

  def load_insights
    shipped_recently = StockMovement.where(kind: "ship", created_at: 60.days.ago(now).beginning_of_day..now)
      .distinct.pluck(:variant_id).to_set
    @dead_stock = stock_rows.select do |variant|
      variant.current_stock.positive? && !shipped_recently.include?(variant.id)
    end
  end

  def load_recent_activity
    @recent_activity = StockMovement.includes(:variant)
      .order(created_at: :desc, id: :desc).limit(10)
  end
end
