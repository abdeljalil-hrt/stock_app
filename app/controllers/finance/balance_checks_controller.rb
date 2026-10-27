module Finance
  class BalanceChecksController < BaseController
    before_action :set_balance_check, only: %i[show create_adjustment]

    def index
      load_index
    end

    def create
      account = Account.find_by(id: params.dig(:balance_check, :account_id), active: true)
      unless account
        redirect_to finance_balance_checks_path, alert: I18n.t("ui.Choose an active account.", default: "Choose an active account.")
        return
      end

      real_cents = ExpenseLineParser.amount_cents(params.dig(:balance_check, :real_balance))
      unless real_cents
        redirect_to finance_balance_checks_path, alert: I18n.t("ui.Enter a valid real balance.", default: "Enter a valid real balance.")
        return
      end

      expected_cents = account.expected_balance_cents
      @balance_check = account.balance_checks.build(
        expected_cents: expected_cents,
        real_cents: real_cents,
        difference_cents: real_cents - expected_cents,
        checked_on: Date.current,
        note: params.dig(:balance_check, :note)
      )

      if @balance_check.save
        redirect_to finance_balance_check_path(@balance_check), notice: I18n.t("ui.Balance check saved.", default: "Balance check saved.")
      else
        load_index
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @history = BalanceCheck.includes(:account).order(created_at: :desc).limit(30)
    end

    def create_adjustment
      if @balance_check.balanced? || @balance_check.adjustment_transaction
        redirect_to finance_balance_check_path(@balance_check)
        return
      end

      category = Category.find_or_create_by!(name: "Other")
      Transaction.transaction do
        adjustment = Transaction.create!(
          date: @balance_check.checked_on,
          amount_cents: @balance_check.difference_cents.abs,
          kind: @balance_check.difference_cents.negative? ? "expense" : "income",
          category: category,
          account: @balance_check.account,
          note: "Balance adjustment"
        )
        @balance_check.update!(adjustment_transaction: adjustment)
      end

      redirect_to finance_balance_check_path(@balance_check), notice: I18n.t("ui.Balance adjustment created.", default: "Balance adjustment created.")
    end

    private

    def set_balance_check
      @balance_check = BalanceCheck.includes(:account, :adjustment_transaction).find(params[:id])
    end

    def load_index
      @accounts = Account.where(active: true).order(:name)
      totals = Transaction.group(:account_id, :kind).sum(:amount_cents)
      @expected_balances = @accounts.index_with do |account|
        account.opening_balance_cents +
          totals.fetch([account.id, "income"], 0) -
          totals.fetch([account.id, "expense"], 0)
      end
      @checks = BalanceCheck.includes(:account).order(created_at: :desc).limit(30)
    end
  end
end
