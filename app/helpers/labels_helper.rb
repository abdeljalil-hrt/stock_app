require "barby/barcode/code_128"
require "barby/outputter/png_outputter"
require "base64"

module LabelsHelper
  def barcode_data_uri(sku)
    image = Barby::Code128B.new(sku).to_png(height: 45, xdim: 2, margin: 2)
    "data:image/png;base64,#{Base64.strict_encode64(image)}"
  end
end
