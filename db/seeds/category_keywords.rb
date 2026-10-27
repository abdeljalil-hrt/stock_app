{
  "ads" => "Ads",
  "advertising" => "Ads",
  "marketing" => "Ads",
  "packaging" => "Packaging",
  "box" => "Packaging",
  "transport" => "Transport",
  "delivery" => "Transport",
  "fuel" => "Transport",
  "wifi" => "Internet",
  "internet" => "Internet",
  "product" => "Cost of goods",
  "inventory" => "Cost of goods",
  "supplier" => "Cost of goods"
}.each do |keyword, category_name|
  category = Category.find_by!(name: category_name)
  CategoryKeyword.find_or_create_by!(keyword: keyword) { |entry| entry.category = category }
end
