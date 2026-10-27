class PurchaseOrderCost < ApplicationRecord
  belongs_to :purchase_order, inverse_of: :costs
  belongs_to :account, optional: true
  belongs_to :linked_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true

  validates :kind, inclusion: { in: PurchaseOrder::COST_KINDS }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def inventory_category_name
    { "freight" => "Delivery", "customs" => "Customs", "local_transport" => "Transport", "other" => "Other" }.fetch(kind)
  end

  def register_payment!(on: paid_on, account: self.account)
    raise ActiveRecord::RecordInvalid, self if amount_cents.to_i <= 0 || on.blank? || account.blank?

    category = Category.find_or_create_by!(name: inventory_category_name)
    self.class.transaction do
      update!(paid_on: on, account: account)
      expense = Transaction.create!(
        date: on,
        amount_cents: amount_cents,
        kind: "expense",
        category: category,
        account: account,
        note: "PO #{purchase_order.number} #{kind.tr("_", " ")}",
        purchase_order: purchase_order
      )
      update!(linked_transaction: expense)
    end
  end
end
