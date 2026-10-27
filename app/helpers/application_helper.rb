module ApplicationHelper
  def ui(text)
    I18n.t(text, scope: :ui, default: text)
  end

  def format_money(amount_cents)
    amount = amount_cents.to_i
    whole, cents = amount.divmod(100)
    formatted_whole = number_with_delimiter(whole, delimiter: " ")
    formatted_amount = cents.zero? ? formatted_whole : "#{formatted_whole}.#{cents.to_s.rjust(2, "0")}"
    "#{formatted_amount} DH"
  end
end
