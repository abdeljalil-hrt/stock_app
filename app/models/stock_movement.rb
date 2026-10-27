class StockMovement < ApplicationRecord
  KINDS = %w[ship return_good return_damaged restock opening adjustment].freeze
  SCAN_KINDS = %w[ship return_good return_damaged restock].freeze
  RETURN_KINDS = %w[return_good return_damaged].freeze
  FIXED_QUANTITIES = {
    "ship" => -1,
    "return_good" => 1,
    "return_damaged" => 0,
    "restock" => 1
  }.freeze

  belongs_to :variant

  validates :kind, inclusion: { in: KINDS }
  validates :quantity, numericality: { only_integer: true }
  validate :quantity_matches_kind
  validate :shipping_does_not_make_stock_negative
  validate :referenced_return_matches_an_unreturned_shipment

  private

  def quantity_matches_kind
    expected = FIXED_QUANTITIES[kind]
    return if expected.nil? || quantity == expected

    errors.add(:quantity, "must be #{expected} for #{kind}")
  end

  def shipping_does_not_make_stock_negative
    return unless kind == "ship" && variant && quantity == -1
    return if variant.stock >= 1

    errors.add(:base, "Cannot ship when stock is zero")
  end

  def referenced_return_matches_an_unreturned_shipment
    return unless RETURN_KINDS.include?(kind) && reference.present? && variant

    shipments = variant.stock_movements.where(kind: "ship", reference: reference).count
    returns = variant.stock_movements.where(kind: RETURN_KINDS, reference: reference).count
    return if returns < shipments

    errors.add(:base, "No unreturned shipment matches this reference")
  end
end
