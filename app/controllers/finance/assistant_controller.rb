module Finance
  class AssistantController < BaseController
    MAX_QUESTION_LENGTH = 1_000

    def show
      @answer = nil
    end

    def create
      @question = params[:question].to_s.strip.first(MAX_QUESTION_LENGTH)
      if @question.blank?
        @error = "Enter a question for the assistant."
        render :show, status: :unprocessable_entity
        return
      end

      data = BusinessAssistantContext.new.payload
      @answer = Ai::BusinessAssistantClient.new.answer(question: @question, business_data: data)
      render :show
    rescue Ai::BusinessAssistantClient::ConfigurationError => error
      @error = error.message
      render :show, status: :service_unavailable
    rescue Ai::BusinessAssistantClient::ProviderError => error
      @error = error.message
      render :show, status: :bad_gateway
    end
  end
end
