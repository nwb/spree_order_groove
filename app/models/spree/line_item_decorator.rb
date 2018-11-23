Spree::LineItem.class_eval do

  attr_accessor :subscription_frequency_id

  #after_create :create_subscription!, if: :subscribable?
  #after_update :update_subscription_quantity, if: :can_update_subscription_quantity?
  #after_update :update_subscription_attributes, if: :can_update_subscription_attributes?
  after_destroy :destroy_associated_subscription!, if: :subscription?

  def subscription_attributes_present?
    subscription_frequency_id.present?
  end

  def updatable_subscription_attributes
    {
      subscription_frequency_id: frequency || subscription.subscription_frequency_id,
    }
  end

  def subscribable?
    auto_delivery && frequency.present?
  end

  def subscription?
    !!subscription
  end

  def subscription
    order.subscriptions.find_by(variant: variant)
  end

  def create_subscription!
    subscription= order.subscriptions.create! subscription_attributes
    subscription.update(
        source: order.payments.from_credit_card.last.source,
        enabled: true,
        ship_address: order.ship_address.clone,
        bill_address: order.bill_address.clone
    )
  end
  
  private



    def subscription_attributes
      ad_adjust=adjustments.eligible.where(label:"Promotion (Auto Delivery)").last["amount"] / quantity
      {
        subscription_frequency_id: frequency,
        price: price + ad_adjust,
        variant: variant,
        quantity: quantity,
        user_id: order.user_id
      }
    end

    def update_subscription_quantity
      subscription.update(quantity: quantity)
    end

    def update_subscription_attributes
      subscription.update(updatable_subscription_attributes)
    end

    def destroy_associated_subscription!
      subscription.destroy!
    end

    def can_update_subscription_attributes?
      subscription? && subscription_attributes_present?
    end

    def can_update_subscription_quantity?
      subscription? && quantity_changed?
    end

end
