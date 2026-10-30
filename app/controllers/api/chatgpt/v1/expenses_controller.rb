module Api
  module Chatgpt
    module V1
      class ExpensesController < BaseController
        MAX_TRANSACTIONS = 100

        def index
          if invalid_date_param?(:start_date) || invalid_date_param?(:end_date)
            return render json: { error: "Dates must use YYYY-MM-DD format." }, status: :unprocessable_entity
          end

          start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
          end_date = parse_date(params[:end_date]) || Date.current
          if start_date > end_date
            return render json: { error: "start_date must be on or before end_date." }, status: :unprocessable_entity
          end

          transactions = Transaction.joins(:category, :account)
            .where(kind: "expense", date: start_date..end_date)
            .where.not(id: PurchaseOrderCost.where.not(transaction_id: nil).select(:transaction_id))
            .where.not(categories: { kind: %w[cost_of_goods transfer] })
            .includes(:category, :account)
            .order(date: :desc, id: :desc)

          total_cents = transactions.sum(:amount_cents)
          by_category = transactions.group("categories.name").sum(:amount_cents)
          entries = transactions.limit(MAX_TRANSACTIONS).map do |transaction|
            {
              date: transaction.date.iso8601,
              amount_cents: transaction.amount_cents,
              category: transaction.category.name,
              account: transaction.account.name,
              note: transaction.note
            }
          end

          render json: {
            start_date: start_date.iso8601,
            end_date: end_date.iso8601,
            total_cents: total_cents,
            total_amount: (total_cents / 100.0).round(2),
            currency: "MAD",
            transaction_count: transactions.count,
            totals_by_category: by_category.sort.map { |name, amount| { category: name, amount_cents: amount, amount: (amount / 100.0).round(2) } },
            transactions: entries,
            transactions_truncated: transactions.count > MAX_TRANSACTIONS
          }
        end

        private

        def parse_date(value)
          return if value.blank?

          Date.iso8601(value)
        rescue ArgumentError
          nil
        end

        def invalid_date_param?(name)
          value = params[name]
          value.present? && parse_date(value).nil?
        end
      end
    end
  end
end
