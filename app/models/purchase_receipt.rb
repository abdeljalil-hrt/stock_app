class PurchaseReceipt < ApplicationRecord
  belongs_to :purchase_order_line, inverse_of: :receipts

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :received_on, presence: true
end
