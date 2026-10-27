class HistoryController < ApplicationController
  def index
    @reference = params[:reference].to_s.strip
    @movements = StockMovement.includes(:variant).order(created_at: :desc, id: :desc)
    if @reference.present?
      @movements = @movements.where(
        "reference ILIKE ?",
        "%#{ActiveRecord::Base.sanitize_sql_like(@reference)}%"
      )
    end
  end
end
