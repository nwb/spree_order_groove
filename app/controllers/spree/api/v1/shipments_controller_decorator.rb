Spree::Api::V1::ShipmentsController.class_eval do

  def add
    quantity = params[:quantity].to_i
    if params[:options]
      options = params[:options]
    end
    options ||= {}
    options[:shipment] = @shipment

    @shipment.order.contents.add(variant, quantity, options)
    respond_with(@shipment, default_template: :show)
  end

end
