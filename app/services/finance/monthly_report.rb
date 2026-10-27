module Finance
  class MonthlyReport
    ExpenseRow = Struct.new(:category, :amount_cents, :percent, :previous_cents, :change_cents, :change_percent, keyword_init: true)
    PotRow = Struct.new(:pot, :income_cents, :expense_cents, keyword_init: true) do
      def net_cents
        income_cents - expense_cents
      end
    end

    attr_reader :month, :income_cents, :shipped_cogs_cents, :returns_cents,
      :gross_margin_cents, :gross_margin_percent, :running_expenses_cents,
      :net_profit_cents, :giving_cents, :expenses_by_category, :pot_allocations

    def initialize(month)
      @month = month.beginning_of_month
      @range = @month...@month.next_month
      @previous_range = @month.prev_month...@month
      calculate
    end

    private

    def calculate
      @income_cents = Transaction.joins(:category)
        .where(kind: "income", date: @range)
        .where.not(categories: { kind: "transfer" })
        .sum(:amount_cents)
      @shipped_cogs_cents = StockMovement.where(kind: "ship", created_at: @range)
        .sum("ABS(quantity) * COALESCE(unit_cost_cents, 0)")
      @returns_cents = StockMovement.where(kind: "return_good", created_at: @range)
        .sum("ABS(quantity) * COALESCE(unit_cost_cents, 0)")

      current_expenses = expense_totals(@range)
      previous_expenses = expense_totals(@previous_range)
      total_expenses = current_expenses.values.sum
      category_ids = (current_expenses.keys + previous_expenses.keys).uniq
      categories = Category.where(id: category_ids).index_by(&:id)
      @expenses_by_category = category_ids.filter_map do |category_id|
        category = categories[category_id]
        next unless category

        amount = current_expenses.fetch(category_id, 0)
        previous = previous_expenses.fetch(category_id, 0)
        change_percent = previous.positive? ? ((amount - previous) * 100.0 / previous).round(1) : nil
        ExpenseRow.new(
          category: category,
          amount_cents: amount,
          percent: total_expenses.positive? ? (amount * 100.0 / total_expenses).round(1) : 0,
          previous_cents: previous,
          change_cents: amount - previous,
          change_percent: change_percent
        )
      end.sort_by { |row| [-row.amount_cents, row.category.name] }
      @running_expenses_cents = total_expenses
      @gross_margin_cents = @income_cents - @shipped_cogs_cents + @returns_cents
      @gross_margin_percent = @income_cents.positive? ? (@gross_margin_cents * 100.0 / @income_cents).round(1) : nil
      @net_profit_cents = @gross_margin_cents - @running_expenses_cents
      @giving_cents = @net_profit_cents.positive? ? ((@net_profit_cents * 5 + 50) / 100) : 0
      @pot_allocations = load_pot_allocations
    end

    def expense_totals(range)
      Transaction.joins(:category)
        .where(kind: "expense", date: range)
        .where(purchase_order_id: nil)
        .where.not(categories: { kind: %w[cost_of_goods transfer] })
        .group(:category_id)
        .sum(:amount_cents)
    end

    def load_pot_allocations
      totals = Transaction.where(date: @range)
        .where.not(pot_id: nil)
        .group(:pot_id, :kind)
        .sum(:amount_cents)
      pots = Pot.where(id: totals.keys.map(&:first).uniq).index_by(&:id)
      totals.keys.map(&:first).uniq.filter_map do |pot_id|
        pot = pots[pot_id]
        next unless pot

        PotRow.new(
          pot: pot,
          income_cents: totals.fetch([pot_id, "income"], 0),
          expense_cents: totals.fetch([pot_id, "expense"], 0)
        )
      end.sort_by { |row| row.pot.name }
    end
  end
end
