class MonthClosure < ApplicationRecord
  validates :month, presence: true, uniqueness: true
  validates :closed_at, presence: true
  validates :net_profit_cents, :giving_cents, numericality: { only_integer: true }
  validates :giving_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_month

  private

  def normalize_month
    self.month = month&.beginning_of_month
  end
end
