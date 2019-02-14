Spree::Order.class_eval do
  has_one :order_subscription, class_name: "Spree::OrderSubscription", dependent: :destroy
  has_one :parent_subscription, through: :order_subscription, source: :subscription
  has_many :subscriptions, class_name: "Spree::Subscription",
           foreign_key: :parent_order_id,
           dependent: :restrict_with_error
  after_update :create_subscriptions

  self.state_machine.after_transition to: :complete, do: :enable_subscriptions, if: :any_disabled_subscription?

  #after_update :update_subscriptions

  def available_payment_methods
    if Spree::Promotion::Rules::Autodelivery.new.eligible?(self)
      @available_payment_methods ||= Spree::PaymentMethod.available(:front_end, store).reject{|p| p.payment_source_class != Spree::CreditCard}
    else
      @available_payment_methods ||= Spree::PaymentMethod.available(:front_end, store)
    end
  end

  def create_subscriptions
    if state=="complete" && !!user_id && payments.completed.from_credit_card.length>0
    line_items.each do |line_item|
      line_item.create_subscription! if line_item.subscribable? && !line_item.subscription
    end
      end
  end

  private

  def enable_subscriptions
    subscriptions.each do |subscription|
      subscription.update(
          source: payments.from_credit_card.first.source,
          enabled: true,
          ship_address: ship_address.clone,
          bill_address: bill_address.clone
      )
    end
  end



  def any_disabled_subscription?
    subscriptions.disabled.any?
  end

  def update_subscriptions
    line_items.each do |line_item|
      if line_item.subscription_attributes_present?
        subscriptions.find_by(variant: line_item.variant).update(line_item.updatable_subscription_attributes)
      end
    end
  end

end
