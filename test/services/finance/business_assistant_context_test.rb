require "test_helper"

module Finance
  class BusinessAssistantContextTest < ActiveSupport::TestCase
    test "returns bounded inventory, movement, and monthly finance data" do
      variant = Variant.create!(sku: "ASSISTANT-TEST", name: "Assistant case", design: "TEST", phone_model: "IP15", low_stock_threshold: 2)
      variant.stock_movements.create!(kind: "opening", quantity: 1)

      payload = BusinessAssistantContext.new(now: Time.zone.local(2026, 10, 29)).payload

      assert_equal %i[inventory stock_movements monthly_finance], payload.keys
      assert_operator payload[:stock_movements].length, :<=, BusinessAssistantContext::MAX_MOVEMENTS
      assert_equal BusinessAssistantContext::MAX_MONTHS, payload[:monthly_finance].length
      assert payload[:inventory][:low_stock].any? { |row| row[:sku] == "ASSISTANT-TEST" }
      assert payload[:monthly_finance].all? { |month| month.key?(:income_cents) && month.key?(:net_profit_cents) }
    end

    test "building context does not change business records" do
      assert_no_changes -> { Variant.count } do
        assert_no_changes -> { StockMovement.count } do
          assert_no_changes -> { Transaction.count } do
            BusinessAssistantContext.new(now: Time.zone.local(2026, 10, 29)).payload
          end
        end
      end
    end
  end
end
