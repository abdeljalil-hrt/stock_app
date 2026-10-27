class CategoryKeyword < ApplicationRecord
  belongs_to :category

  before_validation :normalize_keyword

  validates :keyword, presence: true, uniqueness: { case_sensitive: false }

  private

  def normalize_keyword
    self.keyword = ActiveSupport::Inflector.transliterate(keyword.to_s).downcase.strip
  end
end
