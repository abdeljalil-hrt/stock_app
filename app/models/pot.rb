class Pot < ApplicationRecord
  has_many :transactions, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
