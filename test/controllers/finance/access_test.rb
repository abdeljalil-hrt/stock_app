require "test_helper"

module Finance
  class AccessTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.create!(
        email_address: "finance@example.test",
        password: "test-password",
        password_confirmation: "test-password"
      )
      sign_in(@user)
    end

    test "all finance pages redirect non-owners to the stock dashboard" do
      [
        finance_overview_path,
        finance_expenses_path,
        finance_purchase_orders_path,
        finance_balance_checks_path,
        finance_reports_path,
        finance_settings_path
      ].each do |path|
        get path
        assert_redirected_to dashboard_path
      end
    end

    test "non-owners do not see finance links or group in the sidebar" do
      get dashboard_path

      assert_response :success
      assert_select "h2", text: "Finance", count: 0
      assert_select "a[href^='/finance']", count: 0
    end

    test "finance pages require authentication" do
      delete session_path

      get finance_overview_path

      assert_redirected_to new_session_path
    end

    test "owners can view the finance overview and see finance navigation" do
      @user.update!(owner: true)

      get finance_overview_path

      assert_response :success
      assert_select "h1", text: "Finance overview"
      assert_select "a[href='#{finance_expenses_path}']", text: "Add expense"
      assert_select "h2", text: "Finance", minimum: 1
      assert_select "a[href='#{finance_expenses_path}']", minimum: 1
      assert_select "p", text: "Stock value", minimum: 1
    end

    test "owners can access each finance section and active links follow the current route" do
      @user.update!(owner: true)
      paths = [
        finance_overview_path,
        finance_expenses_path,
        finance_purchase_orders_path,
        finance_balance_checks_path,
        finance_reports_path,
        finance_settings_path
      ]

      paths.each do |path|
        get path

        assert_response :success
        assert_select "aside nav a.bg-gray-100[href='#{path}']", minimum: 1
      end
    end

    private

    def sign_in(user)
      post session_path, params: {
        email_address: user.email_address,
        password: "test-password"
      }
    end
  end
end
