class LocalesController < ApplicationController
  skip_before_action :require_authentication

  def update
    locale = params[:locale].to_s
    unless I18n.available_locales.map(&:to_s).include?(locale)
      return redirect_back fallback_location: root_path, alert: "Unsupported language."
    end

    session[:locale] = locale
    redirect_back fallback_location: root_path
  end
end
