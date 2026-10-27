class LabelsController < ApplicationController
  def index
    @variants = Variant.order(:sku)
  end
end
