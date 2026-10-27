module Finance
  class PurchaseOrdersController < BaseController
    before_action :set_purchase_order, only: %i[show edit update mark_ordered add_cost receive]

    def index
      @purchase_orders = PurchaseOrder.includes(:lines, :costs).order(number: :desc)
    end

    def new
      @purchase_order = PurchaseOrder.new
      @purchase_order.lines.build
      build_default_costs
      load_options
    end

    def create
      @purchase_order = PurchaseOrder.new(purchase_order_params)
      load_options
      assign_lines(@purchase_order, params[:lines])
      assign_costs(@purchase_order, params[:costs])
      @purchase_order.status = "ordered" if params[:commit_action] == "ordered"
      @purchase_order.ordered_on ||= Date.current if @purchase_order.status == "ordered"

      if PurchaseOrder.transaction { @purchase_order.save && record_paid_costs }
        redirect_to finance_purchase_order_path(@purchase_order), notice: I18n.t("ui.Supplier order saved.", default: "Supplier order saved.")
      else
        ensure_form_rows
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @purchase_order.costs.reload
      @lines = @purchase_order.lines.includes(:variant, :receipts).order(:id)
      @accounts = Account.order(:name)
      @cost = @purchase_order.costs.build(paid_on: Date.current)
    end

    def edit
      if @purchase_order.purchase_receipts.exists?
        return redirect_to finance_purchase_order_path(@purchase_order), alert: I18n.t("ui.Received orders cannot be edited.", default: "Received orders cannot be edited.")
      end

      @purchase_order.lines.load
      build_default_costs
      load_options
    end

    def update
      if @purchase_order.purchase_receipts.exists?
        return redirect_to finance_purchase_order_path(@purchase_order), alert: I18n.t("ui.Received orders cannot be edited.", default: "Received orders cannot be edited.")
      end

      load_options
      assign_lines(@purchase_order, params[:lines])
      assign_costs(@purchase_order, params[:costs])
      @purchase_order.assign_attributes(purchase_order_params)
      @purchase_order.status = "ordered" if params[:commit_action] == "ordered"
      @purchase_order.ordered_on ||= Date.current if @purchase_order.status == "ordered"
      if PurchaseOrder.transaction { @purchase_order.save && record_paid_costs }
        redirect_to finance_purchase_order_path(@purchase_order), notice: I18n.t("ui.Supplier order saved.", default: "Supplier order saved.")
      else
        ensure_form_rows
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_ordered
      return redirect_to finance_purchase_order_path(@purchase_order) unless @purchase_order.status == "draft"

      @purchase_order.update!(status: "ordered", ordered_on: @purchase_order.ordered_on || Date.current)
      redirect_to finance_purchase_order_path(@purchase_order), notice: I18n.t("ui.Supplier order marked as ordered.", default: "Supplier order marked as ordered.")
    end

    def add_cost
      amount = ExpenseLineParser.amount_cents(params.dig(:cost, :amount))
      cost = @purchase_order.costs.build(
        kind: params.dig(:cost, :kind),
        amount_cents: amount,
        paid_on: params.dig(:cost, :paid_on),
        account_id: params.dig(:cost, :account_id)
      )
      if cost.save
        cost.register_payment!
        redirect_to finance_purchase_order_path(@purchase_order), notice: I18n.t("ui.Cost added and recorded.", default: "Cost added and recorded.")
      else
        redirect_to finance_purchase_order_path(@purchase_order), alert: cost.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordInvalid => error
      redirect_to finance_purchase_order_path(@purchase_order), alert: error.record.errors.full_messages.to_sentence
    end

    def receive
      quantities = params.fetch(:received, {}).to_unsafe_h
      received_on = Date.current

      PurchaseOrder.transaction do
        @purchase_order.lines.includes(:variant, :receipts).find_each do |line|
          amount = quantities.fetch(line.id.to_s, "0").to_i
          next if amount.zero?

          already_received = line.receipts.sum(:quantity)
          raise ActiveRecord::RecordInvalid, line if amount.negative? || already_received + amount > line.quantity

          line.variant.with_lock do
            current_stock = [line.variant.stock, 0].max
            landed_unit_cost = @purchase_order.landed_unit_cost_cents(line)
            old_cost_cents = (line.variant.cost_price.to_d * 100).round.to_i
            new_stock = current_stock + amount
            weighted_cost = ((current_stock * old_cost_cents) + (amount * landed_unit_cost)).to_f / new_stock

            line.receipts.create!(quantity: amount, received_on: received_on)
            amount.times do
              line.variant.stock_movements.create!(
                kind: "restock",
                quantity: 1,
                reference: "PO #{@purchase_order.number}",
                note: "Purchase order receipt",
                unit_cost_cents: landed_unit_cost
              )
            end
            line.variant.update!(cost_price: BigDecimal(weighted_cost.to_s) / 100)
          end
        end
        if @purchase_order.lines.all? { |line| line.receipts.sum(:quantity) == line.quantity }
          @purchase_order.update!(status: "received")
        else
          @purchase_order.update!(status: "ordered")
        end
      end

      redirect_to finance_purchase_order_path(@purchase_order), notice: I18n.t("ui.Receipt recorded.", default: "Receipt recorded.")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to finance_purchase_order_path(@purchase_order), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_purchase_order
      @purchase_order = PurchaseOrder.includes(:costs, lines: [:variant, :receipts]).find(params[:id])
    end

    def purchase_order_params
      params.require(:purchase_order).permit(:supplier, :ordered_on, :expected_on, :note)
    end

    def load_options
      @variants = Variant.order(:sku)
      @accounts = Account.order(:name)
    end

    def build_default_costs
      PurchaseOrder::COST_KINDS.each do |kind|
        @purchase_order.costs.build(kind: kind) unless @purchase_order.costs.any? { |cost| cost.kind == kind }
      end
    end

    def assign_lines(order, raw_lines)
      order.lines.to_a.each(&:mark_for_destruction)
      unsafe_hash(raw_lines).each_value do |attributes|
        variant_id = attributes[:variant_id].presence
        quantity = attributes[:quantity].to_i
        unit_price_cents = ExpenseLineParser.amount_cents(attributes[:unit_price])
        next if variant_id.blank? && quantity.zero? && attributes[:unit_price].blank?

        order.lines.build(
          variant_id: variant_id,
          quantity: quantity,
          unit_price_cents: unit_price_cents
        )
      end
    end

    def assign_costs(order, raw_costs)
      unsafe_hash(raw_costs).each do |kind, attributes|
        amount_cents = attributes[:amount].blank? ? 0 : ExpenseLineParser.amount_cents(attributes[:amount])
        cost = order.costs.to_a.find { |entry| entry.kind == kind } || order.costs.build(kind: kind)
        cost.assign_attributes(
          amount_cents: amount_cents || -1,
          paid_on: attributes[:paid_on].presence,
          account_id: attributes[:account_id].presence
        )
      end
    end

    def ensure_form_rows
      @purchase_order.lines.build if @purchase_order.lines.reject(&:marked_for_destruction?).empty?
      build_default_costs
    end

    def record_paid_costs
      @purchase_order.costs.each do |cost|
        next unless cost.amount_cents.positive? && cost.paid_on.present? && cost.account.present?

        if cost.linked_transaction
          cost.linked_transaction.update!(
            date: cost.paid_on,
            amount_cents: cost.amount_cents,
            account: cost.account,
            category: Category.find_or_create_by!(name: cost.inventory_category_name),
            note: "PO #{@purchase_order.number} #{cost.kind.tr("_", " ")}"
          )
        else
          cost.register_payment!
        end
      end
    end

    def unsafe_hash(value)
      return {} if value.nil?

      value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
    end
  end
end
