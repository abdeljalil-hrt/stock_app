module Finance
  class OverviewController < BaseController
    def show
      month_range = Date.current.beginning_of_month...Date.current.next_month.beginning_of_month
      @expenses_this_month = Transaction.expenses.where(date: month_range).sum(:amount_cents)
      @stock_value = if Variant.where.not(cost_price: nil).exists?
        Variant.left_joins(:stock_movements)
          .where.not(cost_price: nil)
          .sum("variants.cost_price * COALESCE(stock_movements.quantity, 0)")
      end
    end
  end
end
