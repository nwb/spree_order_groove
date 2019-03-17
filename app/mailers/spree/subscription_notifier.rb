class Spree::SubscriptionNotifier < Hubspot::TransactionEmail::Mailer

  def notify_confirmation(subscription)
    notify_subscriber(subscription, "subscription_recieved_email_id")
  end

  def notify_cancellation(subscription)
    notify_subscriber(subscription, "subscription_canceled_email_id")
  end

  def notify_for_next_delivery(subscription)
    notify_subscriber(subscription, "subscription_order_reminder_email_id")
  end

  def notify_for_cc_expiration(subscription)
    notify_subscriber(subscription, "subscription_credit_card_expired_email_id")
  end

  def notify_for_oos(subscription)
    notify_subscriber(subscription, "subscription_out_of_stock_email_id")
  end

  def notify_for_placing_error(subscription)
    notify_subscriber(subscription, "subscription_generic_issue_email_id")
  end

  def notify_for_unpaused(subscription)
    notify_subscriber(subscription, "subscription_reactivated_email_id")
  end

  private

  def get_email_id(subscription, email_name)
    from_store=subscription.parent_order.store
    email_id = if from_store.url.include? ".com"
                 SpreeHubspot::Config.send('com_' + email_name)
               elsif from_store.url.include? ".ca"
                 SpreeHubspot::Config.send('ca_' + email_name)
               elsif from_store.url.include? ".uk"
                 SpreeHubspot::Config.send('uk_' + email_name)
               elsif from_store.url.include? ".au"
                 SpreeHubspot::Config.send('au_' + email_name)
               elsif from_store.url.include? ".eu"
                 SpreeHubspot::Config.send('eu_' + email_name)
               end
  end

  def notify_subscriber(subscription, message_name)
    #byebug
    email_id=get_email_id(subscription, message_name)
    contact_properties = []

    custom_properties = [
        #{ name: "email", value: subscription.user.email },
        { name: "number", value: subscription.number },
        #{ name: "product", value: subscription.variant.product.name },
        { name: "next_occurrence_at", value: subscription.next_occurrence_at.strftime("%B %d %Y at %I:%M %p") }
    ]
    begin
    mail(email_id: email_id, message: { to: subscription.user.email }, contact_properties: contact_properties, custom_properties: custom_properties) if email_id
    #mail(email_id: email_id, message: { to: subscription.user.email }) if email_id
    rescue Exception=> e
    end
  end

  def from_address
    "no-reply@example.com"
  end

  def from_store
    subscription.store
  end

end
