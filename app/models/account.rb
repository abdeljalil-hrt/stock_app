class Account < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
