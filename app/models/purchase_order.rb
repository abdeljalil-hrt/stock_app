class PurchaseOrder < ApplicationRecord
  STATUSES = %w[draft ordered received].freeze
  COST_KINDS = %w[freight customs local_transport other].freeze

  has_many :lines, class_name: "PurchaseOrderLine", dependent: :destroy, inverse_of: :purchase_order
  has_many :costs, class_name: "PurchaseOrderCost", dependent: :destroy, inverse_of: :purchase_order
  has_many :transactions, dependent: :nullify
  has_many :purchase_receipts, through: :lines, source: :receipts

  accepts_nested_attributes_for :lines, allow_destroy: true
  accepts_nested_attributes_for :costs, allow_destroy: true

  validates :supplier, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :number, uniqueness: true
  validate :has_at_least_one_line

  before_create :assign_number

  def goods_total_cents
    lines.reject(&:marked_for_destruction?).sum { |line| line.quantity.to_i * line.unit_price_cents.to_i }
  end

  def extras_total_cents
    costs.reject(&:marked_for_destruction?).sum { |cost| cost.amount_cents.to_i }
  end

  def landed_total_cents
    goods_total_cents + extras_total_cents
  end

  def landed_unit_cost_cents(line)
    return line.unit_price_cents.to_i if goods_total_cents.zero?

    allocated_extras = (extras_total_cents * line.goods_total_cents.to_f / goods_total_cents).round
    line.quantity.zero? ? line.unit_price_cents.to_i : line.unit_price_cents.to_i + (allocated_extras.to_f / line.quantity).round
  end

  private

  def assign_number
    self.class.transaction do
      self.class.connection.execute("LOCK TABLE purchase_orders IN EXCLUSIVE MODE")
      self.number ||= self.class.maximum(:number).to_i + 1
    end
  end

  def has_at_least_one_line
    errors.add(:lines, "must include at least one product") if lines.reject(&:marked_for_destruction?).empty?
  end
end
