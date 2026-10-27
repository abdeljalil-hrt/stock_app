require "test_helper"

class ScansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant = Variant.create!(
      sku: "SAU-D1-IP15PRO",
      name: "Phone case",
      design: "D1",
      phone_model: "IP15PRO"
    )
    @variant.stock_movements.create!(kind: "opening", quantity: 4)

    User.create!(
      email_address: "scanner@example.test",
      password: "test-password",
      password_confirmation: "test-password"
    )
    post session_path, params: { email_address: "scanner@example.test", password: "test-password" }
  end

  test "unknown SKU does not create a movement" do
    assert_no_difference "StockMovement.count" do
      post scan_path(:ship), params: { sku: "UNKNOWN-SKU" }
    end

    assert_redirected_to scan_path(:ship)
  end

  test "scan page exposes shipping, return, and barcode label links" do
    get scan_path(:ship)

    assert_response :success
    assert_select "input[data-controller='barcode-scan'][data-action='keydown->barcode-scan#keydown']"
    assert_includes response.body, "Barcode scanners submit automatically"
    assert_select "nav[aria-label='Scan modes'] a[href='#{scan_path(:ship)}']"
    assert_select "nav[aria-label='Scan modes'] a[href='#{scan_path(:return_good)}']"
    assert_select "nav[aria-label='Scan modes'] a[href='#{scan_path(:return_damaged)}']"
    assert_select "nav[aria-label='Scan modes'] a[href='#{labels_path}']"
  end

  test "French dates use the same English month format without missing translations" do
    date = Date.new(2026, 10, 27)
    time = Time.zone.local(2026, 10, 27, 14, 5)

    english_date = I18n.with_locale(:en) { I18n.l(date, format: :short) }
    french_date = I18n.with_locale(:fr) { I18n.l(date, format: :short) }
    english_time = I18n.with_locale(:en) { I18n.l(time, format: :short) }
    french_time = I18n.with_locale(:fr) { I18n.l(time, format: :short) }

    assert_equal english_date, french_date
    assert_equal english_time, french_time
  end

  test "valid scan creates one movement" do
    assert_difference "StockMovement.count", 1 do
      post scan_path(:ship), params: { sku: @variant.sku, reference: "ORDER-1" }
    end

    movement = StockMovement.order(:id).last
    assert_equal "ship", movement.kind
    assert_equal "ORDER-1", movement.reference
    assert_equal 3, @variant.reload.stock
    assert_redirected_to scan_path(:ship, reference: "ORDER-1")
  end

  test "good return scan adds one unit back into stock" do
    assert_difference -> { @variant.reload.stock }, 1 do
      assert_difference "StockMovement.count", 1 do
        post scan_path(:return_good), params: { sku: @variant.sku }
      end
    end

    movement = StockMovement.order(:id).last
    assert_equal "return_good", movement.kind
    assert_equal 1, movement.quantity
    assert_equal 5, @variant.reload.stock
    assert_redirected_to scan_path(:return_good)
  end

  test "restock scan mode is no longer available" do
    get "/scan/restock"

    assert_response :not_found
  end

  test "undo removes the last scan movement" do
    post scan_path(:ship), params: { sku: @variant.sku }
    assert_equal 3, @variant.reload.stock

    assert_difference "StockMovement.count", -1 do
      post undo_scan_path
    end

    assert_equal 4, @variant.reload.stock
    assert_equal 0, @variant.stock_movements.where(kind: "ship").count
  end
end
