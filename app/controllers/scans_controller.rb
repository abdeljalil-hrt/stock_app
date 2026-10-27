class ScansController < ApplicationController
  before_action :set_mode, only: %i[show create]

  def show
    @reference = params[:reference].to_s
    @movements = StockMovement
      .where(kind: StockMovement::SCAN_KINDS)
      .includes(:variant)
      .order(created_at: :desc, id: :desc)
      .limit(10)
  end

  def create
    code = params[:sku].to_s.strip.upcase
    variant = Variant.find_by(sku: code)

    unless variant
      return redirect_to scan_path(@mode, reference: params[:reference]),
        alert: I18n.t("scan.unknown_sku", sku: code.presence || "(blank)")
    end

    movement = nil
    new_stock = nil

    variant.with_lock do
      movement = variant.stock_movements.build(
        kind: @mode,
        quantity: StockMovement::FIXED_QUANTITIES.fetch(@mode),
        reference: params[:reference].to_s.strip.presence,
        unit_cost_cents: @mode == "ship" && variant.cost_price.present? ? (variant.cost_price.to_d * 100).round.to_i : nil
      )
      new_stock = variant.stock if movement.save
    end

    if movement.persisted?
      redirect_to scan_path(@mode, reference: params[:reference]),
        notice: I18n.t("scan.success", sku: variant.sku, stock: new_stock)
    else
      redirect_to scan_path(@mode, reference: params[:reference]),
        alert: movement.errors.full_messages.map { |message| I18n.t("scan.errors.#{message}", default: message) }.to_sentence
    end
  end

  def undo
    movement = StockMovement.where(kind: StockMovement::SCAN_KINDS)
      .order(created_at: :desc, id: :desc)
      .first

    unless movement
      return redirect_to scan_path(:ship), alert: I18n.t("scan.nothing_to_undo")
    end

    variant = movement.variant
    sku = variant.sku
    variant.with_lock do
      latest = StockMovement.where(kind: StockMovement::SCAN_KINDS)
        .order(created_at: :desc, id: :desc)
        .first
      if latest&.id == movement.id
        movement.destroy!
      else
        movement = nil
      end
    end

    if movement
      redirect_to scan_path(:ship), notice: I18n.t("scan.undone", sku: sku)
    else
      redirect_to scan_path(:ship), alert: I18n.t("scan.newer_scan")
    end
  end

  private

  def set_mode
    @mode = params[:mode]
  end
end
