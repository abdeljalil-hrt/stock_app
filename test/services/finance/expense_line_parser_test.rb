require "test_helper"

module Finance
  class ExpenseLineParserTest < ActiveSupport::TestCase
    test "parses the four quick-entry examples and matches categories" do
      categories = {
        "Ads" => "expense",
        "Packaging" => "expense",
        "Transport" => "expense",
        "Internet" => "expense"
      }.to_h { |name, kind| [name, Category.create!(name: name, kind: kind)] }
      {
        "ads" => categories.fetch("Ads"),
        "packaging" => categories.fetch("Packaging"),
        "transport" => categories.fetch("Transport"),
        "wifi" => categories.fetch("Internet")
      }.each do |keyword, category|
        CategoryKeyword.create!(keyword: keyword, category: category)
      end

      results = ExpenseLineParser.new(today: Date.new(2026, 10, 27)).parse_lines(
        "1000 ads\n200 packaging\n50 transport to warehouse\n150 wifi"
      )

      assert_equal [100_000, 20_000, 5_000, 15_000], results.map(&:amount_cents)
      assert_equal %w[ads packaging transport internet], results.map { |line| line.category.name.downcase }
      assert_equal ["ads", "packaging", "transport to warehouse", "wifi"], results.map(&:description)
      assert_equal [Date.new(2026, 10, 27)] * 4, results.map(&:date)
    end

    test "parses grouped and decimal amounts and optional trailing tokens" do
      account = Account.create!(name: "Cash")
      category = Category.create!(name: "Transport")
      CategoryKeyword.create!(keyword: "transport", category: category)
      result = ExpenseLineParser.new(accounts: [account], default_account: nil, today: Date.new(2026, 10, 27))
        .parse("1 000.50 transport yesterday Cash po123")

      assert_equal 100_050, result.amount_cents
      assert_equal "transport", result.description
      assert_equal Date.new(2026, 10, 26), result.date
      assert_equal account, result.account
      assert_equal "po123", result.purchase_order_reference
    end

    test "parses a dh suffix and uses the longest matching keyword" do
      general = Category.create!(name: "Transport")
      warehouse = Category.create!(name: "Warehouse transport")
      CategoryKeyword.create!(keyword: "transport", category: general)
      CategoryKeyword.create!(keyword: "transport to warehouse", category: warehouse)

      result = ExpenseLineParser.new(today: Date.new(2026, 10, 27)).parse("1000dh transport to warehouse")

      assert_equal 100_000, result.amount_cents
      assert_equal warehouse, result.category
    end
  end
end
