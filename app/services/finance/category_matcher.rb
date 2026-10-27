module Finance
  class CategoryMatcher
    def initialize(keywords: CategoryKeyword.includes(:category))
      @keywords = keywords.to_a
    end

    def match(text)
      normalized_text = normalize(text)
      @keywords
        .select { |entry| normalized_text.include?(entry.keyword) }
        .max_by { |entry| entry.keyword.length }
        &.category
    end

    def self.normalize(text)
      ActiveSupport::Inflector.transliterate(text.to_s).downcase
    end

    private

    def normalize(text)
      self.class.normalize(text)
    end
  end
end
