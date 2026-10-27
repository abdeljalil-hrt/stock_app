require "test_helper"

module Finance
  class ExpensesControllerTest < ActionDispatch::IntegrationTest
    setup do
      user = User.create!(
        email_address: "expense-entry@example.test",
        password: "test-password",
        password_confirmation: "test-password",
        owner: true
      )
      post session_path, params: { email_address: user.email_address, password: "test-password" }

      @account = Account.create!(name: "Cash")
      @ads = Category.create!(name: "Ads")
      @packaging = Category.create!(name: "Packaging")
      @transport = Category.create!(name: "Transport")
      @internet = Category.create!(name: "Internet")
      @cost_of_goods = Category.create!(name: "Cost of goods", kind: "cost_of_goods")
      CategoryKeyword.create!(keyword: "ads", category: @ads)
      CategoryKeyword.create!(keyword: "packaging", category: @packaging)
      CategoryKeyword.create!(keyword: "transport", category: @transport)
      CategoryKeyword.create!(keyword: "wifi", category: @internet)
      CategoryKeyword.create!(keyword: "product", category: @cost_of_goods)
    end

    test "preview parses four lines and save all creates them together" do
      post finance_expense_preview_path, params: { lines: "1000 ads\n200 packaging\n50 transport to warehouse\n150 wifi" }

      assert_response :success
      assert_select "form[action='#{finance_expense_save_all_path}'] tbody tr", 4
      assert_select "select[name='expenses[0][category_id]'] option[selected]", text: "Ads"

      assert_difference "Transaction.count", 4 do
        post finance_expense_save_all_path, params: {
          expenses: preview_params(
            ["1000 ads", @ads],
            ["200 packaging", @packaging],
            ["50 transport to warehouse", @transport],
            ["150 wifi", @internet]
          )
        }
      end

      assert_redirected_to finance_expenses_path
      follow_redirect!
      assert_response :success
      assert_select "[role='status']", text: "4 expenses saved."
      assert_select "tbody tr", 4
      assert_includes response.body, "1 000 DH"
      assert_includes response.body, "transport to warehouse"
    end

    test "unmatched line requires a category and selected category is saved as a keyword" do
      post finance_expense_preview_path, params: { lines: "75 mystery" }
      assert_select "option[selected]", text: "Needs category"

      post finance_expense_save_all_path, params: {
        expenses: { "0" => expense_row("75 mystery", category_id: "", account_id: @account.id) }
      }
      assert_response :unprocessable_entity

      post finance_expense_save_all_path, params: {
        expenses: { "0" => expense_row("75 mystery", category_id: @transport.id, account_id: @account.id) }
      }

      assert_redirected_to finance_expenses_path
      assert_equal @transport, CategoryKeyword.find_by!(keyword: "mystery").category
    end

    test "cost of goods without a purchase order is blocked" do
      post finance_expense_preview_path, params: { lines: "600 product" }

      assert_response :success
      assert_includes response.body, "Link to a supplier order?"

      assert_no_difference "Transaction.count" do
        post finance_expense_save_all_path, params: {
          expenses: {
            "0" => expense_row("600 product", category_id: @cost_of_goods.id, account_id: @account.id)
          }
        }
      end
      assert_response :unprocessable_entity
      assert_includes response.body, "supplier order"
    end

    test "expenses list shows saved transactions and supports month and category filters" do
      transaction = Transaction.create!(
        date: Date.current,
        amount_cents: 10_000,
        category: @ads,
        account: @account,
        note: "campaign"
      )

      get finance_expenses_path, params: { category_id: @ads.id, month: Date.current.strftime("%Y-%m") }

      assert_response :success
      assert_includes response.body, "campaign"
      assert_includes response.body, "100 DH"
      assert_select "a[href='#{edit_finance_expense_path(transaction)}']"
    end

    test "single expense form stores cents and existing expenses can be edited and deleted" do
      post finance_expenses_path, params: {
        transaction: {
          date: Date.current.iso8601,
          amount: "25.50",
          category_id: @ads.id,
          account_id: @account.id,
          note: "single entry"
        }
      }

      transaction = Transaction.order(:id).last
      assert_equal 2_550, transaction.amount_cents
      assert_redirected_to finance_expenses_path

      get edit_finance_expense_path(transaction)
      assert_response :success
      patch finance_expense_path(transaction), params: {
        transaction: { amount: "30", category_id: @ads.id, account_id: @account.id }
      }
      assert_equal 3_000, transaction.reload.amount_cents
      assert_redirected_to finance_expenses_path

      assert_difference "Transaction.count", -1 do
        delete finance_expense_path(transaction)
      end
    end

    private

    def expense_row(line, category_id:, account_id:)
      {
        line: line,
        date: Date.current.iso8601,
        category_id: category_id,
        account_id: account_id,
        purchase_order_reference: ""
      }
    end

    def preview_params(*lines)
      lines.each_with_index.to_h do |(line, category), index|
        [index.to_s, expense_row(line, category_id: category.id, account_id: @account.id)]
      end
    end
  end
end
