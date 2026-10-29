require "csv"

models = %w[
  IP11 IP12 IP12PRO IP12PROMAX IP13 IP13PRO IP13PROMAX IP14 IP14PRO IP14PROMAX
  IP15 IP15PRO IP15PROMAX IP16 IP16PRO IP16PROMAX IP17 IP17PRO IP17PROMAX
]

models.each do |phone_model|
  previous_variant = Variant.find_by(sku: "SAU-D1-#{phone_model}")
  next unless previous_variant

  new_sku = "SAU-PINK-#{phone_model}"
  if Variant.exists?(sku: new_sku)
    raise "Cannot rename #{previous_variant.sku}: #{new_sku} already exists"
  end

  previous_variant.update!(
    sku: new_sku,
    name: "Pink #{phone_model} phone case",
    design: "PINK"
  )
end

models.each do |phone_model|
  previous_variant = Variant.find_by(sku: "SAU-D2-#{phone_model}")
  next unless previous_variant

  new_sku = "SAU-MIRROR-#{phone_model}"
  if Variant.exists?(sku: new_sku)
    raise "Cannot rename #{previous_variant.sku}: #{new_sku} already exists"
  end

  previous_variant.update!(
    sku: new_sku,
    name: "Mirror #{phone_model} phone case",
    design: "MIRROR"
  )
end

{ "PINK" => "Pink", "MIRROR" => "Mirror", "BLUE" => "Blue", "LENS" => "Lens", "BLOOM" => "Bloom", "BUTTERFLY" => "Butterfly" }.each do |design, label|
  models.each do |phone_model|
    sku = "SAU-#{design}-#{phone_model}"
    Variant.find_or_create_by!(sku: sku) do |variant|
      variant.name = "#{label} #{phone_model} phone case"
      variant.design = design
      variant.phone_model = phone_model
    end
  end
end

Variant.find_or_create_by!(sku: "SAU-STRAP") do |variant|
  variant.name = "Strap with card holder"
  variant.design = "STRAP"
  variant.phone_model = "UNIVERSAL"
end

CSV.foreach(Rails.root.join("db/stock.csv"), headers: true) do |row|
  variant = Variant.find_by!(sku: row.fetch("sku").to_s.strip.upcase)
  quantity = row.fetch("quantity").to_s.strip.presence || "0"
  opening = variant.stock_movements.find_or_initialize_by(kind: "opening", reference: "db/stock.csv")
  opening.quantity = Integer(quantity, 10)
  opening.save! if opening.new_record? || opening.will_save_change_to_quantity?
end

email = ENV["STOCK_APP_EMAIL"].to_s.strip
password = ENV["STOCK_APP_PASSWORD"].to_s
if email.present? || password.present?
  raise "Set both STOCK_APP_EMAIL and STOCK_APP_PASSWORD to create the first user" if email.blank? || password.blank?

  User.find_or_create_by!(email_address: email) do |user|
    user.password = password
    user.password_confirmation = password
    user.owner = User.none?
  end
end

load Rails.root.join("db/seeds/finance.rb")
[Rails.root.join("db/seeds/category_keywords.rb"), Rails.root.join("category_keywords.rb")].each do |path|
  load path if path.file?
end
