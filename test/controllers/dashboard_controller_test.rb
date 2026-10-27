require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(
      email_address: "dashboard@example.test",
      password: "test-password",
      password_confirmation: "test-password"
    )
    post session_path, params: { email_address: user.email_address, password: "test-password" }
  end

  test "dashboard loads for a logged-in user with selected period" do
    get dashboard_path, params: { period: "7" }

    assert_response :success
    assert_no_match(/DH|MAD|Stock value/, response.body)
    assert_select "h1", "Dashboard"
    assert_select "select[name='period'] option[selected][value='7']"
    assert_select "aside nav a.bg-gray-100", text: "Dashboard"
  end

  test "stock page does not display variant cost prices" do
    Variant.create!(
      sku: "SAU-PINK-IP15",
      name: "Phone case",
      design: "PINK",
      phone_model: "IP15",
      cost_price: 123.45
    )

    get stock_index_path

    assert_response :success
    assert_no_match(/123\.45|cost_price|DH|MAD/, response.body)
  end

  test "root redirects to dashboard" do
    get root_path

    assert_redirected_to dashboard_path
  end

  test "dashboard redirects unauthenticated users to login" do
    delete session_path
    get dashboard_path

    assert_redirected_to new_session_path
  end

  test "sidebar section is active for legacy stock and history routes and all scan modes" do
    {
      variants_path => "Stock",
      scan_path(:ship) => "Scan",
      scan_path(:return_good) => "Scan",
      stock_movements_path => "History"
    }.each do |path, label|
      get path

      assert_response :success
      assert_select "aside nav a.bg-gray-100", text: label
    end
  end

  test "sign-in page does not render the sidebar" do
    delete session_path
    get new_session_path

    assert_response :success
    assert_select "aside", count: 0
  end

  test "sign-in page remains sidebar-free even when visited with a session" do
    get new_session_path

    assert_response :success
    assert_select "aside", count: 0
  end

  test "stock page filters low and out of stock rows" do
    get stock_index_path, params: { status: "out" }

    assert_response :success
    assert_select "h1", "Out of stock"
  end
end
