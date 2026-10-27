class Account < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_exception
  has_many :balance_checks, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :opening_balance_cents, numericality: { only_integer: true }

  def expected_balance_cents
    totals = transactions.group(:kind).sum(:amount_cents)
    opening_balance_cents + totals.fetch("income", 0) - totals.fetch("expense", 0)
  end
end
