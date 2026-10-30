require "test_helper"

module Ai
  class BusinessAssistantClientTest < ActiveSupport::TestCase
    test "uses the configured API key as a bearer token" do
      api_key = "test-key-not-a-real-secret"
      client = BusinessAssistantClient.new(api_key: api_key, endpoint: "https://provider.example.test/v1/chat/completions")
      response = http_response(200, { "choices" => [{ "message" => { "content" => "Analysis" } }] }.to_json)
      request = nil

      with_http_response(response) do |http|
        http.define_singleton_method(:request) do |submitted_request|
          request = submitted_request
          response
        end
        assert_equal "Analysis", client.answer(question: "Summarize stock", business_data: {})
      end

      assert_equal true, request["Authorization"] == "Bearer #{api_key}"
      assert_equal true, request["Authorization"] != "******"
    end

    test "successful response missing message content is a provider error" do
      client = BusinessAssistantClient.new(api_key: "test-key", endpoint: "https://provider.example.test/v1/chat/completions")

      [{}, { "choices" => [] }, { "choices" => [{ "message" => {} }] }, { "choices" => [{ "message" => { "content" => 123 } }] }].each do |body|
        response = http_response(200, body.to_json)

        with_http_response(response) do |http|
          http.define_singleton_method(:request) { |_request| response }
          error = assert_raises(BusinessAssistantClient::ProviderError) do
            client.answer(question: "Summarize stock", business_data: {})
          end
          assert_equal "AI provider returned a malformed response", error.message
        end
      end
    end

    test "successful response with message content is returned" do
      client = BusinessAssistantClient.new(api_key: "test-key", endpoint: "https://provider.example.test/v1/chat/completions")
      response = http_response(200, { "choices" => [{ "message" => { "content" => "  Valid analysis  " } }] }.to_json)

      with_http_response(response) do |http|
        http.define_singleton_method(:request) { |_request| response }
        assert_equal "Valid analysis", client.answer(question: "Summarize stock", business_data: {})
      end
    end

    private

    def http_response(status, body)
      response = Net::HTTPOK.new("1.1", status.to_s, "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
      response
    end

    def with_http_response(_response)
      http = Object.new
      original_start = Net::HTTP.method(:start)
      Net::HTTP.define_singleton_method(:start) do |*_args, **_kwargs, &block|
        block.call(http)
      end
      yield http
    ensure
      Net::HTTP.define_singleton_method(:start, original_start) if original_start
    end
  end
end
