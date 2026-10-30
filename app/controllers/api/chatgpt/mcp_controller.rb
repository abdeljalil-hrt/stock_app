module Api
  module Chatgpt
    class McpController < ApplicationController
      allow_unauthenticated_access
      skip_before_action :verify_authenticity_token
      before_action :authenticate_action_key!

      PROTOCOL_VERSION = "2025-03-26"

      def create
        message = JSON.parse(request.raw_post)
        return head :accepted if message["method"].to_s.start_with?("notifications/")

        result = dispatch(message)

        render json: { jsonrpc: "2.0", id: message["id"], result: result }
      rescue JSON::ParserError
        render json: { jsonrpc: "2.0", id: nil, error: { code: -32700, message: "Parse error" } }, status: :bad_request
      rescue ArgumentError => error
        render json: { jsonrpc: "2.0", id: message&.[]("id"), error: { code: -32602, message: error.message } }, status: :unprocessable_entity
      end

      private

      def authenticate_action_key!
        configured_key = ENV["CHATGPT_MCP_API_KEY"].to_s
        return render(json: { error: "ChatGPT API access is not configured." }, status: :service_unavailable) if configured_key.blank?

        supplied_key = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1].to_s
        valid = supplied_key.bytesize == configured_key.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied_key, configured_key)
        return if valid

        response.set_header("WWW-Authenticate", 'Bearer realm="Stock app"')
        render json: { error: "Unauthorized." }, status: :unauthorized
      end

      def dispatch(message)
        case message["method"]
        when "initialize"
          { protocolVersion: PROTOCOL_VERSION, capabilities: { tools: {} }, serverInfo: { name: "stock-app", version: "1.0.0" } }
        when "ping"
          {}
        when "tools/list"
          { tools: tool_definitions }
        when "tools/call"
          call_tool(message.fetch("params", {}))
        else
          raise ArgumentError, "Unknown method: #{message['method']}"
        end
      end

      def tool_definitions
        [
          {
            name: "get_inventory",
            description: "Read current stock by SKU. Optionally provide one SKU to look up a single variant.",
            inputSchema: {
              type: "object",
              properties: { sku: { type: "string", description: "Optional SKU, case insensitive." } },
              additionalProperties: false
            },
            annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false }
          },
          {
            name: "get_expenses",
            description: "Read recorded running expenses for one month, grouped by category. Defaults to the current month. Excludes stock purchase costs and transfers.",
            inputSchema: {
              type: "object",
              properties: { month: { type: "string", pattern: "^\\d{4}-\\d{2}$", description: "Optional month in YYYY-MM format." } },
              additionalProperties: false
            },
            annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false }
          }
        ]
      end

      def call_tool(params)
        data = case params["name"]
        when "get_inventory"
          inventory_data(params.fetch("arguments", {}))
        when "get_expenses"
          expense_data(params.fetch("arguments", {}))
        else
          return { isError: true, content: [{ type: "text", text: "Unknown tool." }] }
        end

        { content: [{ type: "text", text: JSON.generate(data) }], structuredContent: data }
      end

      def inventory_data(arguments)
        variants = Variant.left_joins(:stock_movements)
          .select("variants.id, variants.sku, variants.name, variants.phone_model, variants.design, variants.low_stock_threshold, COALESCE(SUM(stock_movements.quantity), 0) AS quantity_on_hand")
          .group("variants.id").order(:sku)
        variants = variants.where("LOWER(variants.sku) = ?", arguments["sku"].to_s.strip.downcase) if arguments["sku"].present?
        rows = variants.map do |variant|
          quantity = variant.quantity_on_hand.to_i
          { sku: variant.sku, name: variant.name, phone_model: variant.phone_model, design: variant.design,
            quantity_on_hand: quantity, low_stock_threshold: variant.low_stock_threshold, low_stock: quantity <= variant.low_stock_threshold }
        end
        { as_of: Time.current.iso8601, total_units: rows.sum { |row| row[:quantity_on_hand] }, variants: rows }
      end

      def expense_data(arguments)
        month = arguments["month"].present? ? Date.strptime(arguments["month"], "%Y-%m") : Date.current.beginning_of_month
        raise ArgumentError, "Month must use YYYY-MM format." unless month.day == 1 && arguments["month"].to_s.match?(/\A\d{4}-\d{2}\z/)

        report = Finance::MonthlyReport.new(month)
        {
          month: month.strftime("%Y-%m"), currency: "MAD", total_cents: report.running_expenses_cents,
          total_amount: (report.running_expenses_cents / 100.0).round(2),
          by_category: report.expenses_by_category.map do |row|
            { category: row.category.name, amount_cents: row.amount_cents, amount: (row.amount_cents / 100.0).round(2) }
          end
        }
      rescue Date::Error
        raise ArgumentError, "Month must use YYYY-MM format."
      end
    end
  end
end
