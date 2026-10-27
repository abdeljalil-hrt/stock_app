require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(
      email_address: "locale@example.test",
      password: "test-password",
      password_confirmation: "test-password"
    )
    post session_path, params: { email_address: user.email_address, password: "test-password" }
  end

  test "language button switches interface to French and back" do
    post locale_path(:fr), headers: { "HTTP_REFERER" => dashboard_url }

    assert_redirected_to dashboard_url
    follow_redirect!
    assert_response :success
    assert_select "html[lang='fr']"
    assert_select "h1", "Tableau de bord"
    assert_select "button", "English"

    post locale_path(:en), headers: { "HTTP_REFERER" => dashboard_url }
    follow_redirect!

    assert_select "html[lang='en']"
    assert_select "h1", "Dashboard"
  end

  test "unsupported locale is rejected without changing language" do
    post locale_path(:es), headers: { "HTTP_REFERER" => dashboard_url }
    follow_redirect!

    assert_select "html[lang='en']"
  end
end
