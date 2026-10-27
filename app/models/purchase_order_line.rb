class PurchaseOrderLine < ApplicationRecord
  belongs_to :purchase_order, inverse_of: :lines
  belongs_to :variant
  has_many :receipts, class_name: "PurchaseReceipt", dependent: :destroy, inverse_of: :purchase_order_line

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def goods_total_cents
    quantity.to_i * unit_price_cents.to_i
  end

  def received_quantity
    receipts.sum(:quantity)
  end
end
