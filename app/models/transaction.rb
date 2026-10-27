class Transaction < ApplicationRecord
  belongs_to :category
  belongs_to :account
  belongs_to :pot, optional: true
  belongs_to :purchase_order, optional: true

  validates :date, :amount_cents, :kind, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :kind, inclusion: { in: %w[expense income] }
  validate :cost_of_goods_requires_purchase_order

  scope :expenses, -> { where(kind: "expense") }

  def amount
    amount_cents && BigDecimal(amount_cents.to_s) / 100
  end

  def amount=(value)
    self.amount_cents = Finance::ExpenseLineParser.amount_cents(value)
  end

  private

  def cost_of_goods_requires_purchase_order
    return unless category&.kind == "cost_of_goods"
    return if purchase_order_reference.to_s.match?(/\Apo\d+\z/i)

    errors.add(:purchase_order_reference, "must link a supplier order (po<number>)")
  end
end
