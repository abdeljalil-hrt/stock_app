class PurchaseOrderLine < ApplicationRecord
  belongs_to :purchase_order, inverse_of: :lines
  belongs_to :variant, optional: true
  has_many :receipts, class_name: "PurchaseReceipt", dependent: :destroy, inverse_of: :purchase_order_line

  attr_accessor :product_entry

  validate :variant_must_be_selected
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def goods_total_cents
    quantity.to_i * unit_price_cents.to_i
  end

  def received_quantity
    receipts.sum(:quantity)
  end

  private

  def variant_must_be_selected
    errors.add(:base, "Choose a product from the catalog by SKU or unique name") unless variant
  end
end
