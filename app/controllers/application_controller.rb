class ApplicationController < ActionController::Base
  include Authentication

  before_action :set_locale

  private

  def set_locale
    I18n.locale = session[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end
end
