require "test_helper"

module Finance
  class BalanceChecksControllerTest < ActionDispatch::IntegrationTest
    setup do
      user = User.create!(
        email_address: "balance-check@example.test",
        password: "test-password",
        password_confirmation: "test-password",
        owner: true
      )
      post session_path, params: { email_address: user.email_address, password: "test-password" }
      @account = Account.create!(name: "Bank", opening_balance_cents: 10_000)
    end

    test "shows active account expected balance and accepts a real balance form" do
      @account.update!(active: false)
      active_account = Account.create!(name: "Cash", opening_balance_cents: 20_000)
      income = Category.create!(name: "Sales", kind: "income")
      Transaction.create!(date: Date.current, amount_cents: 3_000, kind: "income", category: income, account: active_account)
      expense = Category.create!(name: "Supplies")
      Transaction.create!(date: Date.current, amount_cents: 1_000, category: expense, account: active_account)

      get finance_balance_checks_path

      assert_response :success
      assert_includes response.body, "220 DH"
      assert_not_includes response.body, "Bank"

      post finance_balance_checks_path, params: {
        balance_check: { account_id: active_account.id, real_balance: "200", note: "Counted cash" }
      }

      check = BalanceCheck.order(:id).last
      assert_redirected_to finance_balance_check_path(check)
      assert_equal 22_000, check.expected_cents
      assert_equal 20_000, check.real_cents
      assert_equal(-2_000, check.difference_cents)
      assert_equal "Counted cash", check.note
    end

    test "creates one linked expense adjustment for missing balance" do
      post finance_balance_checks_path, params: {
        balance_check: { account_id: @account.id, real_balance: "80" }
      }
      check = BalanceCheck.order(:id).last
      assert_redirected_to finance_balance_check_path(check)

      assert_difference "Transaction.count", 1 do
        post create_adjustment_finance_balance_check_path(check)
      end
      adjustment = check.reload.adjustment_transaction
      assert_equal "expense", adjustment.kind
      assert_equal 2_000, adjustment.amount_cents
      assert_equal "Balance adjustment", adjustment.note
      assert_equal @account, adjustment.account
      assert_redirected_to finance_balance_check_path(check)

      assert_no_difference "Transaction.count" do
        post create_adjustment_finance_balance_check_path(check)
      end
    end

    test "legacy hyphenated path redirects to canonical underscore route" do
      get "/finance/balance-check"

      assert_redirected_to "/finance/balance_checks"
    end
  end
end
