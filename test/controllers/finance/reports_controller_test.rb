require "test_helper"

module Finance
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      user = User.create!(
        email_address: "reports@example.test",
        password: "test-password",
        password_confirmation: "test-password",
        owner: true
      )
      post session_path, params: { email_address: user.email_address, password: "test-password" }
      @month = Date.current.beginning_of_month
      @account = Account.create!(name: "Report cash")
      @income = Category.create!(name: "Sales", kind: "income")
      @expense = Category.create!(name: "Advertising")
    end

    test "loads report data, category comparison, pots, and CSV export" do
      Transaction.create!(date: @month + 4.days, amount_cents: 10_000, kind: "income", category: @income, account: @account)
      Transaction.create!(date: @month + 4.days, amount_cents: 2_000, category: @expense, account: @account)
      Transaction.create!(date: @month.prev_month + 4.days, amount_cents: 1_000, category: @expense, account: @account)
      pot = Pot.create!(name: "Packaging")
      Transaction.create!(date: @month + 4.days, amount_cents: 500, kind: "expense", category: @expense, account: @account, pot: pot)

      variant = Variant.create!(sku: "REPORT-CASE", name: "Report case", design: "D1", phone_model: "IP15", cost_price: 20)
      variant.stock_movements.create!(kind: "opening", quantity: 1)
      variant.stock_movements.create!(kind: "ship", quantity: -1, reference: "REPORT-1", unit_cost_cents: 2_000, created_at: @month + 5.days)
      variant.stock_movements.create!(kind: "return_good", quantity: 1, reference: "REPORT-1", unit_cost_cents: 2_000, created_at: @month + 6.days)

      get finance_reports_path(month: @month.strftime("%Y-%m"))

      assert_response :success
      assert_includes response.body, "100 DH"
      assert_includes response.body, "20 DH"
      assert_includes response.body, "75 DH"
      assert_includes response.body, "100%"
      assert_includes response.body, "Packaging"
      assert_includes response.body, "Change vs previous month"

      get export_finance_reports_path(month: @month.strftime("%Y-%m"))
      assert_response :success
      assert_equal "text/csv", response.media_type
      assert_includes response.body, "Cost of goods"
      assert_includes response.body, "Sales"
    end

    test "empty month has zero metrics and an empty transaction state" do
      empty_month = Date.current.next_year.beginning_of_month

      get finance_reports_path(month: empty_month.strftime("%Y-%m"))

      assert_response :success
      assert_includes response.body, "0 DH"
      assert_includes response.body, "No transactions for this month."
      assert_includes response.body, "—"
    end

    test "closes a profitable month once and records both sides of the giving transfer" do
      Transaction.create!(date: @month + 2.days, amount_cents: 10_000, kind: "income", category: @income, account: @account)

      assert_difference "MonthClosure.count", 1 do
        assert_difference "Transaction.count", 2 do
          post close_month_finance_reports_path, params: { month: @month.strftime("%Y-%m") }
        end
      end
      closure = MonthClosure.find_by!(month: @month)
      assert_equal 500, closure.giving_cents
      transfers = Transaction.where(note: "Month close transfer #{@month.strftime("%Y-%m")}")
      assert_equal ["expense", "income"], transfers.order(:kind).pluck(:kind)
      assert_equal 500, Pot.find_by!(name: "Giving").transactions.sum(:amount_cents)
      assert_equal 500, Pot.find_by!(name: "Profit safety").transactions.sum(:amount_cents)
      assert_redirected_to finance_reports_path(month: @month.strftime("%Y-%m"))

      assert_no_difference ["MonthClosure.count", "Transaction.count"] do
        post close_month_finance_reports_path, params: { month: @month.strftime("%Y-%m") }
      end
      get finance_reports_path(month: @month.strftime("%Y-%m"))
      assert_select "button[disabled]", text: "Month already closed"
      assert_includes response.body, "5 DH"
    end
  end
end
