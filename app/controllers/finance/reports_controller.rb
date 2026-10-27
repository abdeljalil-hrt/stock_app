require "csv"

module Finance
  class ReportsController < BaseController
    before_action :set_month, only: %i[index export close_month]

    def index
      @report = MonthlyReport.new(@month)
      @closure = MonthClosure.find_by(month: @month)
      @transactions = monthly_transactions
    end

    def export
      report = MonthlyReport.new(@month)
      transactions = monthly_transactions
      csv = CSV.generate do |rows|
        rows << ["Summary", "Metric", "Value (cents)"]
        [
          ["Income", report.income_cents],
          ["Cost of goods", report.shipped_cogs_cents],
          ["Returns cost", report.returns_cents],
          ["Gross margin", report.gross_margin_cents],
          ["Running expenses", report.running_expenses_cents],
          ["Net profit", report.net_profit_cents],
          ["Giving", report.giving_cents]
        ].each { |metric, value| rows << ["Summary", metric, value] }
        rows << []
        rows << ["Transactions"]
        rows << ["Date", "Category", "Kind", "Amount (cents)", "Account", "Pot", "Note"]
        transactions.each do |transaction|
          rows << [
            transaction.date,
            safe_csv_text(transaction.category.name),
            transaction.kind,
            transaction.amount_cents,
            safe_csv_text(transaction.account.name),
            safe_csv_text(transaction.pot&.name),
            safe_csv_text(transaction.note)
          ]
        end
      end

      send_data csv, filename: "finance-report-#{@month.strftime("%Y-%m")}.csv", type: "text/csv"
    end

    def close_month
      report = MonthlyReport.new(@month)
      if MonthClosure.exists?(month: @month)
        redirect_to finance_reports_path(month: month_param), alert: I18n.t("ui.This month is already closed.", default: "This month is already closed.")
        return
      end

      account = Account.where(active: true).order(:id).first
      if report.giving_cents.positive? && account.nil?
        redirect_to finance_reports_path(month: month_param), alert: I18n.t("ui.Create an active account before closing a profitable month.", default: "Create an active account before closing a profitable month.")
        return
      end

      MonthClosure.transaction do
        MonthClosure.create!(
          month: @month,
          net_profit_cents: report.net_profit_cents,
          giving_cents: report.giving_cents,
          closed_at: Time.current
        )
        create_giving_transfer!(report, account) if report.giving_cents.positive?
      end

      redirect_to finance_reports_path(month: month_param), notice: I18n.t("ui.Month closed.", default: "Month closed.")
    end

    private

    def set_month
      @month = if params[:month].present?
        Date.strptime(params[:month], "%Y-%m").beginning_of_month
      else
        Date.current.beginning_of_month
      end
    rescue Date::Error
      @month = Date.current.beginning_of_month
    end

    def month_param
      @month.strftime("%Y-%m")
    end

    def monthly_transactions
      Transaction.where(date: @month...@month.next_month)
        .includes(:category, :account, :pot)
        .order(:date, :id)
    end

    def create_giving_transfer!(report, account)
      giving_pot = Pot.find_or_create_by!(name: "Giving")
      safety_pot = Pot.find_or_create_by!(name: "Profit safety")
      category = Category.find_or_initialize_by(name: "Pot transfer")
      category.kind = "transfer"
      category.save!
      transfer_date = @month.end_of_month
      note = "Month close transfer #{@month.strftime("%Y-%m")}"

      Transaction.create!(
        date: transfer_date,
        amount_cents: report.giving_cents,
        kind: "income",
        category: category,
        account: account,
        pot: giving_pot,
        note: note
      )
      Transaction.create!(
        date: transfer_date,
        amount_cents: report.giving_cents,
        kind: "expense",
        category: category,
        account: account,
        pot: safety_pot,
        note: note
      )
    end

    def safe_csv_text(value)
      text = value.to_s
      text.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text
    end
  end
end
