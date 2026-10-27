require "test_helper"

class DashboardStatsTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.local(2026, 10, 27, 12)
  end

  test "calculates shipped totals, returns, and return rate for selected period" do
    variant = create_variant("SAU-PINK-IP11", "PINK", "IP11")
    add_movement(variant, "opening", 10)
    3.times { add_movement(variant, "ship", -1) }
    add_movement(variant, "return_good", 1)
    add_movement(variant, "return_damaged", 0)
    add_movement(variant, "ship", -1, created_at: 40.days.ago(@now))

    stats = DashboardStats.new(period: 30, now: @now)

    assert_equal 3, stats.kpis[:shipped]
    assert_equal 2, stats.kpis[:returns]
    assert_equal 1, stats.kpis[:damaged]
    assert_equal 66.7, stats.kpis[:return_rate]
    assert_equal 3, stats.shipments_by_day.values.sum
    assert_includes stats.returns_by_week.values, 66.7
  end

  test "calculates days of cover and reorder quantity including no-shipment and zero-stock cases" do
    average, cover, reorder = DashboardStats.reorder_metrics(stock: 2, shipped: 4)
    assert_in_delta 4.0 / 30, average
    assert_in_delta 15, cover
    assert_equal 2, reorder

    _average, zero_stock_cover, zero_stock_reorder =
      DashboardStats.reorder_metrics(stock: 0, shipped: 4)
    assert_equal 0, zero_stock_cover
    assert_equal 4, zero_stock_reorder

    no_sales_average, no_sales_cover, no_sales_reorder =
      DashboardStats.reorder_metrics(stock: 8, shipped: 0)
    assert_equal 0, no_sales_average
    assert_nil no_sales_cover
    assert_equal 0, no_sales_reorder
  end

  test "reorder rows use current stock and include only variants with recent shipments" do
    active = create_variant("SAU-PINK-IP12", "PINK", "IP12")
    dormant = create_variant("SAU-MIRROR-IP12", "MIRROR", "IP12")
    sold_out = create_variant("SAU-PINK-IP15", "PINK", "IP15")
    add_movement(active, "opening", 6)
    4.times { add_movement(active, "ship", -1) }
    add_movement(sold_out, "opening", 4)
    4.times { add_movement(sold_out, "ship", -1) }
    add_movement(dormant, "opening", 8)

    stats = DashboardStats.new(period: 30, now: @now)
    item = stats.reorder_items.find { |row| row.variant.id == active.id }
    sold_out_item = stats.reorder_items.find { |row| row.variant.id == sold_out.id }

    assert_equal 2, item.variant.current_stock
    assert_in_delta 15, item.days_cover
    assert_equal 2, item.suggested_order
    assert_equal 0, sold_out_item.variant.current_stock
    assert_equal 0, sold_out_item.days_cover
    assert_equal 4, sold_out_item.suggested_order
    assert_not_includes stats.reorder_items.map(&:variant), dormant
  end

  test "detects positive dead stock and sums only period net adjustments" do
    dead = create_variant("SAU-PINK-IP13", "PINK", "IP13")
    recent = create_variant("SAU-MIRROR-IP13", "MIRROR", "IP13")
    zero = create_variant("SAU-PINK-IP14", "PINK", "IP14")
    add_movement(dead, "opening", 5)
    add_movement(recent, "opening", 5)
    add_movement(recent, "ship", -1, created_at: 59.days.ago(@now))
    add_movement(zero, "opening", 0)
    add_movement(dead, "adjustment", 3)
    add_movement(dead, "adjustment", -1)
    add_movement(dead, "adjustment", 10, created_at: 40.days.ago(@now))

    stats = DashboardStats.new(period: 30, now: @now)

    assert_equal [dead], stats.dead_stock
    assert_equal 2, stats.kpis[:net_adjustments]
  end

  test "empty database returns zero unit metrics and empty series" do
    stats = DashboardStats.new(period: 30, now: @now)

    assert_equal 0, stats.kpis[:units_in_stock]
    assert_equal 0, stats.kpis[:shipped]
    assert_equal "-", stats.kpis[:return_rate]
    assert_not_includes stats.kpis.keys, :stock_value
    assert_empty stats.stock_by_model
    assert_empty stats.top_sellers
    assert_empty stats.reorder_items
    assert_empty stats.dead_stock
  end

  private

  def create_variant(sku, design, phone_model)
    Variant.create!(
      sku: sku,
      design: design,
      phone_model: phone_model,
      name: "#{design} #{phone_model}"
    )
  end

  def add_movement(variant, kind, quantity, created_at: @now)
    variant.stock_movements.create!(kind: kind, quantity: quantity, created_at: created_at)
  end
end
