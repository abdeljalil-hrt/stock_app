require "json"
require "net/http"
require "uri"

module Ai
  class BusinessAssistantClient
    ConfigurationError = Class.new(StandardError)
    ProviderError = Class.new(StandardError)

    def initialize(api_key: ENV["AI_ASSISTANT_API_KEY"], endpoint: ENV.fetch("AI_ASSISTANT_ENDPOINT", "https://api.openai.com/v1/chat/completions"), model: ENV.fetch("AI_ASSISTANT_MODEL", "gpt-4o-mini"))
      @api_key = api_key
      @endpoint = endpoint
      @model = model
    end

    def answer(question:, business_data:)
      raise ConfigurationError, "AI_ASSISTANT_API_KEY is not configured" if @api_key.blank?

      uri = URI.parse(@endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model: @model,
        temperature: 0.2,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "Business data JSON:\n#{JSON.generate(business_data)}\n\nOwner question:\n#{question}" }
        ]
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) do |http|
        http.request(request)
      end
      raise ProviderError, "AI provider returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      choices = body.is_a?(Hash) ? body["choices"] : nil
      message = choices.is_a?(Array) ? choices.first&.is_a?(Hash) && choices.first["message"] : nil
      content = message.is_a?(Hash) ? message["content"] : nil
      raise ProviderError, "AI provider returned a malformed response" unless content.is_a?(String) && content.present?

      content.strip
    rescue JSON::ParserError
      raise ProviderError, "AI provider returned an invalid response"
    rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED
      raise ProviderError, "AI provider is temporarily unavailable"
    end

    private

    def system_prompt
      <<~PROMPT
        You are a read-only business analyst for the owner's stock and finance application.
        Analyze only the supplied JSON business data. Do not claim to have performed any database writes,
        inventory changes, financial transactions, SQL queries, or actions outside the supplied data.
        Do not invent missing values. Label projections as estimates. Keep answers concise and actionable.
      PROMPT
    end
  end
end
