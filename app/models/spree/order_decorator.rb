Spree::Order.class_eval do

  def available_payment_methods
    if Spree::Promotion::Rules::Autodelivery.new.eligible?(self)
      @available_payment_methods ||= Spree::PaymentMethod.available(:front_end, store).reject{|p| p.payment_source_class != Spree::CreditCard}
    else
      @available_payment_methods ||= Spree::PaymentMethod.available(:front_end, store)
    end
  end
end
