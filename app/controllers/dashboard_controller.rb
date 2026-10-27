class DashboardController < ApplicationController
  def show
    @stats = DashboardStats.new(period: params[:period])
  end
end
