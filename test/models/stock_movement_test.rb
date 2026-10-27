require "test_helper"

class StockMovementTest < ActiveSupport::TestCase
  setup do
    @variant = Variant.create!(
      sku: "SAU-D1-IP15PRO",
      name: "Phone case",
      design: "D1",
      phone_model: "IP15PRO"
    )
  end

  test "shipping with zero stock is rejected" do
    movement = @variant.stock_movements.build(kind: "ship", quantity: -1)

    assert_not movement.valid?
    assert_includes movement.errors.full_messages, "Cannot ship when stock is zero"
    assert_equal 0, @variant.stock
  end

  test "return with a reference but no matching shipment is rejected" do
    movement = @variant.stock_movements.build(
      kind: "return_good",
      quantity: 1,
      reference: "ORDER-1"
    )

    assert_not movement.valid?
    assert_includes movement.errors.full_messages, "No unreturned shipment matches this reference"
  end

  test "a shipped item cannot be returned twice against the same reference" do
    @variant.stock_movements.create!(kind: "opening", quantity: 1)
    @variant.stock_movements.create!(kind: "ship", quantity: -1, reference: "ORDER-1")
    @variant.stock_movements.create!(kind: "return_good", quantity: 1, reference: "ORDER-1")
    second_return = @variant.stock_movements.build(
      kind: "return_damaged",
      quantity: 0,
      reference: "ORDER-1"
    )

    assert_not second_return.valid?
    assert_includes second_return.errors.full_messages, "No unreturned shipment matches this reference"
  end

  test "damaged return does not change stock" do
    @variant.stock_movements.create!(kind: "opening", quantity: 1)
    @variant.stock_movements.create!(kind: "ship", quantity: -1, reference: "ORDER-1")

    assert_no_difference -> { @variant.stock } do
      @variant.stock_movements.create!(
        kind: "return_damaged",
        quantity: 0,
        reference: "ORDER-1"
      )
    end
  end
end
