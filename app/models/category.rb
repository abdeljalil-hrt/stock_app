class Category < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_exception
  has_many :category_keywords, dependent: :destroy

  KINDS = %w[expense cost_of_goods income transfer].freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
end
