Spree::StoreController.class_eval do
    protected
      # This method is placed here so that the CheckoutController
      # and OrdersController can both reference it (or any other controller
      # which needs it)
    def apply_autodelivery
      if !!@order && !(["complete", "awaiting_return", "returned"].include? @order.state)
        auto_delivery = cookies[:og_autoship] && cookies[:og_cart_autoship]
        og_ioi = JSON.parse(cookies[:og_cart_autoship] || '[]')

        @order.line_items.each do |l|
           l.auto_delivery = (cookies[:og_autoship]=="1" && (og_ioi.map{|d| d['id']}.include? l.variant_id.to_s))
          l.save
        end

        #@order.save!
        #handler = Spree::PromotionHandler::Autodelivery.new(@order).apply
        #else
        #  @order.autodelivery = nil
        #end
      end
    end

end
