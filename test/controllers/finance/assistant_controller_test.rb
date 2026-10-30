require "test_helper"

module Finance
  class AssistantControllerTest < ActionDispatch::IntegrationTest
    setup do
      @owner = User.create!(email_address: "assistant-owner@example.test", password: "test-password", password_confirmation: "test-password", owner: true)
      @user = User.create!(email_address: "assistant-user@example.test", password: "test-password", password_confirmation: "test-password")
    end

    test "non-owner cannot access the assistant" do
      sign_in(@user)

      get finance_assistant_path
      assert_redirected_to dashboard_path

      post finance_assistant_path, params: { question: "Summarize stock" }
      assert_redirected_to dashboard_path
    end

    test "unauthenticated visitor is redirected to sign in" do
      get finance_assistant_path
      assert_redirected_to new_session_path
    end

    test "owner receives configuration error without mutating business data" do
      sign_in(@owner)
      ENV.delete("AI_ASSISTANT_API_KEY")

      assert_no_changes -> { Transaction.count } do
        assert_no_changes -> { StockMovement.count } do
          post finance_assistant_path, params: { question: "Summarize this month" }
        end
      end

      assert_response :service_unavailable
      assert_includes response.body, "AI_ASSISTANT_API_KEY is not configured"
    end

    test "provider failures are handled without mutating business data" do
      sign_in(@owner)
      ENV["AI_ASSISTANT_API_KEY"] = "test-key"
      ENV["AI_ASSISTANT_ENDPOINT"] = "http://127.0.0.1:1"

      assert_no_changes -> { Transaction.count } do
        assert_no_changes -> { StockMovement.count } do
          post finance_assistant_path, params: { question: "Summarize this month" }
        end
      end

      assert_response :bad_gateway
      assert_includes response.body, "AI provider is temporarily unavailable"
    ensure
      ENV.delete("AI_ASSISTANT_ENDPOINT")
      ENV.delete("AI_ASSISTANT_API_KEY")
    end

    test "blank questions are rejected" do
      sign_in(@owner)

      post finance_assistant_path, params: { question: "   " }

      assert_response :unprocessable_entity
      assert_includes response.body, "Enter a question for the assistant."
    end

    private

    def sign_in(user)
      post session_path, params: { email_address: user.email_address, password: "test-password" }
    end
  end
end
