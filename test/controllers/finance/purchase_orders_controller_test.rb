require "test_helper"

module Finance
  class PurchaseOrdersControllerTest < ActionDispatch::IntegrationTest
    setup do
      user = User.create!(
        email_address: "purchase-order@example.test",
        password: "test-password",
        password_confirmation: "test-password",
        owner: true
      )
      post session_path, params: { email_address: user.email_address, password: "test-password" }
      @account = Account.create!(name: "PO cash")
      @category = Category.create!(name: "Cost of goods", kind: "cost_of_goods")
      @first = Variant.create!(sku: "SAU-PO-PINK-IP15", name: "Pink case", design: "PINK", phone_model: "IP15", cost_price: 80)
      @second = Variant.create!(sku: "SAU-PO-MIRROR-IP15", name: "Mirror case", design: "MIRROR", phone_model: "IP15")
      @first.stock_movements.create!(kind: "opening", quantity: 2)
    end

    test "creates a two-line supplier order with paid costs and partial then full receipts" do
      assert_difference "PurchaseOrder.count", 1 do
        post finance_purchase_orders_path, params: {
          purchase_order: { supplier: "Case Supplier", ordered_on: Date.current.iso8601, expected_on: Date.current.iso8601 },
          commit_action: "ordered",
          lines: {
            "0" => { product: "#{@first.sku} — #{@first.name}", quantity: "4", unit_price: "100" },
            "1" => { product: @second.name, quantity: "2", unit_price: "200" }
          },
          costs: {
            "freight" => { amount: "120", paid_on: Date.current.iso8601, account_id: @account.id },
            "customs" => { amount: "", paid_on: "", account_id: "" },
            "local_transport" => { amount: "", paid_on: "", account_id: "" },
            "other" => { amount: "", paid_on: "", account_id: "" }
          }
        }
      end

      order = PurchaseOrder.order(:number).last
      first_line = order.lines.find_by!(variant: @first)
      second_line = order.lines.find_by!(variant: @second)
      assert_equal "ordered", order.status
      assert_equal 1, order.number
      assert_equal 92_000, order.landed_total_cents
      assert_equal 1, order.costs.count { |cost| cost.linked_transaction.present? }

      post receive_finance_purchase_order_path(order), params: {
        received: { first_line.id.to_s => "2", second_line.id.to_s => "1" }
      }
      assert_redirected_to finance_purchase_order_path(order)
      assert_equal "ordered", order.reload.status
      assert_equal 4, @first.reload.stock
      assert_in_delta BigDecimal("97.5"), @first.cost_price
      assert_equal 2, PurchaseReceipt.count
      assert_equal 3, StockMovement.where(kind: "restock").count

      post receive_finance_purchase_order_path(order), params: {
        received: { first_line.id.to_s => "2", second_line.id.to_s => "1" }
      }
      assert_equal "received", order.reload.status
      assert_equal 6, @first.reload.stock
      assert_in_delta BigDecimal("103.33"), @first.cost_price.round(2)
      assert_equal 4, PurchaseReceipt.count
      assert_equal 6, StockMovement.where(kind: "restock").count
      assert_equal 2, @second.reload.stock
      assert_in_delta BigDecimal("230"), @second.cost_price
    end

    test "supplier orders page has a new order button and shows empty state" do
      get finance_purchase_orders_path

      assert_response :success
      assert_select "a[href='#{new_finance_purchase_order_path}']", text: "New supplier order"
      assert_includes response.body, "No supplier orders yet."
    end

    test "new order has text product, quantity, piece price, freight, and optional customs inputs" do
      get new_finance_purchase_order_path

      assert_response :success
      assert_select "input[type='text'][name='lines[0][product]'][list='purchase-order-products']"
      assert_select "input[type='number'][name='lines[0][quantity]']"
      assert_select "input[type='number'][name='lines[0][unit_price]']"
      assert_includes response.body, "Freight price"
      assert_includes response.body, "Customs (optional; can be added later)"
    end

    test "add cost creates a linked expense transaction" do
      post finance_purchase_orders_path, params: {
        purchase_order: { supplier: "Supplier" },
        lines: { "0" => { product: @first.sku, quantity: "1", unit_price: "50" } }
      }
      order = PurchaseOrder.order(:number).last

      get finance_purchase_order_path(order)
      assert_response :success
      assert_includes response.body, "No additional costs."

      assert_difference "Transaction.count", 1 do
        post add_cost_finance_purchase_order_path(order), params: {
          cost: { kind: "customs", amount: "20", paid_on: Date.current.iso8601, account_id: @account.id }
        }
      end
      transaction = Transaction.order(:id).last
      assert_equal "Customs", transaction.category.name
      assert_equal order, order.costs.find_by!(kind: "customs").purchase_order
      assert_equal transaction, order.costs.find_by!(kind: "customs").linked_transaction
      assert_equal 2_000, transaction.amount_cents

      get finance_purchase_order_path(order)
      assert_response :success
      assert_includes response.body, "Customs"
    end
  end
end
