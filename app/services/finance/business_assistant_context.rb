module Finance
  class BusinessAssistantContext
    MAX_MOVEMENTS = 100
    MAX_MONTHS = 6

    def initialize(now: Time.current)
      @now = now
      @stats = DashboardStats.new(period: 30, now: now)
    end

    def payload
      {
        inventory: inventory_summary,
        stock_movements: recent_stock_movements,
        monthly_finance: monthly_finance
      }
    end

    private

    def inventory_summary
      {
        units_in_stock: @stats.kpis[:units_in_stock],
        units_by_design: @stats.kpis[:units_by_design],
        low_stock: @stats.stock_rows.filter_map do |row|
          next unless row.current_stock <= row.low_stock_threshold
          { sku: row.sku, quantity: row.current_stock, low_stock_threshold: row.low_stock_threshold }
        end.first(50),
        top_sellers_last_30_days: @stats.top_sellers.first(10).filter_map { |variant, quantity| { sku: variant&.sku, quantity: quantity } },
        reorder_suggestions: @stats.reorder_items.first(15).map do |item|
          { sku: item.variant.sku, current_stock: item.variant.current_stock, average_daily: item.average_daily.round(2), suggested_order: item.suggested_order }
        end,
        dead_stock: @stats.dead_stock.first(50).map { |variant| { sku: variant.sku, quantity: variant.current_stock } }
      }
    end

    def recent_stock_movements
      StockMovement.includes(:variant)
        .where(created_at: 30.days.ago(@now.beginning_of_day)..@now)
        .order(created_at: :desc, id: :desc)
        .limit(MAX_MOVEMENTS)
        .map do |movement|
          { sku: movement.variant.sku, kind: movement.kind, quantity: movement.quantity, occurred_at: movement.created_at.iso8601 }
        end
    end

    def monthly_finance
      Array.new(MAX_MONTHS) { |offset| @now.to_date.beginning_of_month.prev_month(offset) }.reverse.filter_map do |month|
        report = Finance::MonthlyReport.new(month)
        {
          month: month.strftime("%Y-%m"),
          income_cents: report.income_cents,
          shipped_cogs_cents: report.shipped_cogs_cents,
          running_expenses_cents: report.running_expenses_cents,
          gross_margin_cents: report.gross_margin_cents,
          net_profit_cents: report.net_profit_cents
        }
      end
    end
  end
end
