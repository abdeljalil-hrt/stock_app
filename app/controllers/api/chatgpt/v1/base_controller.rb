module Api
  module Chatgpt
    module V1
      class BaseController < ApplicationController
        allow_unauthenticated_access
        before_action :authenticate_action_key!

        private

        def authenticate_action_key!
          configured_key = ENV["CHATGPT_MCP_API_KEY"].to_s
          unless configured_key.present?
            return render json: { error: "ChatGPT API access is not configured." }, status: :service_unavailable
          end

          supplied_key = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1].to_s
          valid = supplied_key.bytesize == configured_key.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(supplied_key, configured_key)
          return if valid

          response.set_header("WWW-Authenticate", 'Bearer realm="Stock app"')
          render json: { error: "Unauthorized." }, status: :unauthorized
        end
      end
    end
  end
end
