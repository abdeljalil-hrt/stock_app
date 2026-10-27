module Finance
  class ExpenseLineParser
    ParsedLine = Struct.new(
      :line, :amount_cents, :description, :date, :category, :account,
      :purchase_order_reference, :error, keyword_init: true
    )
    AMOUNT_PATTERN = /\A\s*(?<whole>\d{1,3}(?:[ ]\d{3})+|\d+)(?:[.,](?<fraction>\d{1,2}))?\s*(?:dh)?(?:\s+(?<description>.*))?\z/i

    def initialize(accounts: Account.all, default_account: nil, today: Date.current)
      @accounts = accounts.to_a.sort_by { |account| -account.name.length }
      @default_account = default_account
      @today = today
      @matcher = CategoryMatcher.new
    end

    def parse_lines(text)
      text.to_s.lines.filter_map.with_index(1) do |line, index|
        next if line.strip.empty?

        parse(line.strip, line_number: index)
      end
    end

    def parse(line, line_number: nil)
      match = AMOUNT_PATTERN.match(line.to_s)
      return ParsedLine.new(line: line, error: "Enter an amount at the start of the line.") unless match

      whole = match[:whole].delete(" ").to_i
      fraction = match[:fraction].to_s.ljust(2, "0").to_i
      amount_cents = whole * 100 + fraction
      return ParsedLine.new(line: line, error: "Amount must be greater than zero.") unless amount_cents.positive?

      description = match[:description].to_s.strip
      date = @today
      account = @default_account
      purchase_order_reference = nil
      loop do
        if description.sub!(/\s+(po\d+)\s*\z/i, "")
          purchase_order_reference = Regexp.last_match(1).downcase
        elsif description.sub!(/\s+yesterday\s*\z/i, "")
          date = @today.yesterday
        elsif (matched_account = account_suffix(description))
          description = description[0...-matched_account.name.length].strip
          account = matched_account
        else
          break
        end
      end

      ParsedLine.new(
        line: line,
        amount_cents: amount_cents,
        description: description,
        date: date,
        category: @matcher.match(description),
        account: account,
        purchase_order_reference: purchase_order_reference
      )
    end

    def self.amount_cents(value)
      match = /\A\s*(?<whole>\d{1,3}(?:[ ]\d{3})+|\d+)(?:[.,](?<fraction>\d{1,2}))?\s*(?:dh)?\s*\z/i.match(value.to_s)
      return unless match

      match[:whole].delete(" ").to_i * 100 + match[:fraction].to_s.ljust(2, "0").to_i
    end

    private

    def account_suffix(description)
      normalized_description = CategoryMatcher.normalize(description)
      @accounts.find do |account|
        normalized_account = CategoryMatcher.normalize(account.name)
        normalized_description.end_with?(" #{normalized_account}")
      end
    end
  end
end
