{
  "Ads" => "expense",
  "Packaging" => "expense",
  "Transport" => "expense",
  "Internet" => "expense",
  "Cost of goods" => "cost_of_goods",
  "Other" => "expense"
}.each do |name, kind|
  Category.find_or_create_by!(name: name) { |category| category.kind = kind }
end

%w[Cash Bank].each do |name|
  Account.find_or_create_by!(name: name)
end
