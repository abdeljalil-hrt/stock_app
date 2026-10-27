class BalanceCheck < ApplicationRecord
  belongs_to :account
  belongs_to :adjustment_transaction, class_name: "Transaction", optional: true

  validates :expected_cents, :real_cents, :difference_cents, numericality: { only_integer: true }
  validates :checked_on, presence: true
  validate :difference_matches_balances

  def balanced?
    difference_cents.zero?
  end

  private

  def difference_matches_balances
    return if expected_cents.nil? || real_cents.nil? || difference_cents == real_cents - expected_cents

    errors.add(:difference_cents, "must equal the real balance minus the expected balance")
  end
end
