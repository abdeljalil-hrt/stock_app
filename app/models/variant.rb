class Variant < ApplicationRecord
  has_many :stock_movements, dependent: :destroy

  before_validation :normalize_sku

  validates :sku, presence: true, uniqueness: true
  validates :name, :design, :phone_model, presence: true
  validates :low_stock_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def stock
    stock_movements.sum(:quantity)
  end

  private

  def normalize_sku
    self.sku = sku.to_s.strip.upcase
  end
end
