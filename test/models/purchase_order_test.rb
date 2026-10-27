require "test_helper"

class PurchaseOrderTest < ActiveSupport::TestCase
  test "allocates shared extras in proportion to each line goods value" do
    variant_a = Variant.create!(sku: "LAND-A", name: "A", design: "D", phone_model: "A")
    variant_b = Variant.create!(sku: "LAND-B", name: "B", design: "D", phone_model: "B")
    order = PurchaseOrder.create!(
      supplier: "Supplier",
      lines: [
        PurchaseOrderLine.new(variant: variant_a, quantity: 2, unit_price_cents: 10_000),
        PurchaseOrderLine.new(variant: variant_b, quantity: 2, unit_price_cents: 20_000)
      ],
      costs: [PurchaseOrderCost.new(kind: "freight", amount_cents: 9_000)]
    )

    assert_equal 69_000, order.landed_total_cents
    assert_equal [11_500, 23_000], order.lines.map { |line| order.landed_unit_cost_cents(line) }
  end
end
