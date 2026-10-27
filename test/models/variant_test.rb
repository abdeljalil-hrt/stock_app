require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "normalizes SKU to uppercase and enforces uniqueness" do
    variant = build_variant(sku: " sau-d1-ip15pro ")
    assert variant.save
    assert_equal "SAU-D1-IP15PRO", variant.sku

    duplicate = build_variant(sku: "sau-d1-ip15pro")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sku], "has already been taken"
  end

  test "stock is the sum of its movements" do
    variant = create_variant
    variant.stock_movements.create!(kind: "opening", quantity: 8)
    variant.stock_movements.create!(kind: "ship", quantity: -1)

    assert_equal 7, variant.stock
  end

  private

  def build_variant(sku:)
    Variant.new(sku: sku, name: "Phone case", design: "D1", phone_model: "IP15PRO")
  end

  def create_variant
    build_variant(sku: "SAU-D1-IP15PRO").tap(&:save!)
  end
end
