module Finance
  class ExpensesController < BaseController
    before_action :load_form_options
    before_action :set_expense, only: %i[edit update destroy]

    def index
      @month = parse_month(params[:month])
      @category_id = Category.exists?(id: params[:category_id]) ? params[:category_id] : nil
      @transactions = monthly_expenses
      @transactions = @transactions.where(category_id: @category_id) if @category_id
      @transactions = @transactions.includes(:category, :account, :pot).order(date: :desc, id: :desc)
      @month_total_cents = monthly_expenses.sum(:amount_cents)
      @transaction = Transaction.new(date: Date.current, account_id: @default_account&.id)
      @lines = ""
    end

    def preview
      @month = Date.current.beginning_of_month
      @lines = params[:lines].to_s
      @preview_rows = parser.parse_lines(@lines)
      @transaction = Transaction.new(date: Date.current, account_id: @default_account&.id)
      render :index
    end

    def create
      amount_cents = ExpenseLineParser.amount_cents(params.dig(:transaction, :amount))
      @transaction = Transaction.new(expense_params.except(:amount).merge(amount_cents: amount_cents, kind: "expense"))
      if @transaction.save
        redirect_to finance_expenses_path, notice: I18n.t("ui.Expense saved.", default: "Expense saved.")
      else
        load_expense_list
        @lines = ""
        render :index, status: :unprocessable_entity
      end
    end

    def save_all
      rows = submitted_rows
      parsed = rows.map { |row| [row, parser.parse(row[:line])] }
      transactions = parsed.map do |row, line|
        Transaction.new(
          date: row[:date].presence || line.date,
          amount_cents: line.amount_cents,
          kind: "expense",
          category: Category.find_by(id: row[:category_id]),
          account: Account.find_by(id: row[:account_id]),
          pot: Pot.find_by(id: row[:pot_id]),
          note: line.description.presence,
          purchase_order_reference: row[:purchase_order_reference].presence || line.purchase_order_reference
        )
      end

      parsed.each do |row, line|
        line.error = "Enter an amount at the start of the line." if line.error.nil? && line.amount_cents.nil?
      end
      transactions.each(&:valid?)
      invalid = parsed.any? { |_row, line| line.error.present? } || transactions.any?(&:invalid?)

      if invalid
        @lines = rows.map { |row| row[:line] }.join("\n")
        @preview_rows = preview_rows_from(parsed, transactions)
        @month = Date.current.beginning_of_month
        @transaction = Transaction.new(date: Date.current, account_id: @default_account&.id)
        flash.now[:alert] = I18n.t("ui.Fix the highlighted expenses before saving.", default: "Fix the highlighted expenses before saving.")
        return render :index, status: :unprocessable_entity
      end

      Transaction.transaction do
        transactions.each(&:save!)
        parsed.each_with_index do |(row, line), index|
          next if line.category.present? || transactions[index].category.nil?

          keyword = line.description.to_s.scan(/[[:alpha:]]+/).first
          next if keyword.blank?

          CategoryKeyword.find_or_create_by!(keyword: keyword) do |entry|
            entry.category = transactions[index].category
          end
        end
      end

      redirect_to finance_expenses_path, notice: "#{transactions.size} #{I18n.t("ui.expenses saved.", default: "expenses saved.")}"
    rescue ActiveRecord::RecordInvalid => error
      @lines = rows.to_a.map { |row| row[:line] }.join("\n")
      @preview_rows = preview_rows_from(parsed || [], transactions || [])
      @month = Date.current.beginning_of_month
      @transaction = Transaction.new(date: Date.current, account_id: @default_account&.id)
      flash.now[:alert] = error.record.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end

    def edit
      load_expense_list
      @lines = ""
    end

    def update
      amount_cents = ExpenseLineParser.amount_cents(params.dig(:transaction, :amount))
      if @transaction.update(expense_params.except(:amount).merge(amount_cents: amount_cents))
        redirect_to finance_expenses_path, notice: I18n.t("ui.Expense updated.", default: "Expense updated.")
      else
        load_expense_list
        @lines = ""
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @transaction.destroy!
      redirect_to finance_expenses_path, notice: I18n.t("ui.Expense deleted.", default: "Expense deleted.")
    end

    private

    def load_form_options
      @categories = Category.order(:name)
      @accounts = Account.order(:name)
      @pots = Pot.order(:name)
      last_account_id = Transaction.expenses.order(created_at: :desc).where.not(account_id: nil).pick(:account_id)
      @default_account = @accounts.find { |account| account.id == last_account_id } || @accounts.first
    end

    def load_expense_list
      @month = parse_month(params[:month])
      @category_id = nil
      @transactions = monthly_expenses.includes(:category, :account, :pot).order(date: :desc, id: :desc)
      @month_total_cents = monthly_expenses.sum(:amount_cents)
      @transaction ||= Transaction.new(date: Date.current, account_id: @default_account&.id)
    end

    def monthly_expenses
      Transaction.expenses.where(date: @month.beginning_of_month...@month.next_month.beginning_of_month)
    end

    def parse_month(value)
      value.present? ? Date.strptime(value, "%Y-%m").beginning_of_month : Date.current.beginning_of_month
    rescue Date::Error
      Date.current.beginning_of_month
    end

    def parser
      ExpenseLineParser.new(accounts: @accounts, default_account: @default_account)
    end

    def submitted_rows
      rows = params.require(:expenses)
      rows.keys.sort_by(&:to_i).map do |key|
        rows[key].permit(:line, :date, :category_id, :account_id, :pot_id, :purchase_order_reference)
      end
    end

    def preview_rows_from(parsed_rows, transactions = [])
      parsed_rows.each_with_index.map do |(row, line), index|
        {
          line: line,
          category_id: row[:category_id].presence || line.category&.id || transactions[index]&.category_id,
          account_id: row[:account_id].presence || line.account&.id || transactions[index]&.account_id,
          date: row[:date].presence || line.date,
          purchase_order_reference: row[:purchase_order_reference].presence || line.purchase_order_reference,
          error: line.error || transactions[index]&.errors&.full_messages&.to_sentence
        }
      end
    end

    def expense_params
      params.require(:transaction).permit(:date, :amount, :category_id, :account_id, :pot_id, :note, :purchase_order_reference)
    end

    def set_expense
      @transaction = Transaction.expenses.find(params[:id])
    end
  end
end
