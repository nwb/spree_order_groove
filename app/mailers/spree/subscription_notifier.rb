class Spree::SubscriptionNotifier < Hubspot::TransactionEmail::Mailer

  def notify_confirmation(subscription)
    contact_properties = []

    custom_properties = [
        { name: "number", value: subscription.number },
        { name: "next_occurrence_at", value: subscription.next_occurrence_at.strftime("%B %d %Y at %I:%M %p") }
    ]
    notify_subscriber(subscription, "subscription_recieved_email_id", contact_properties, custom_properties)
  end

  def notify_cancellation(subscription)
    contact_properties = []

    custom_properties = [
        { name: "number", value: subscription.number },
        { name: "cancellation_reasons", value: subscription.cancellation_reasons }
    ]
    notify_subscriber(subscription, "subscription_canceled_email_id", contact_properties, custom_properties)
  end

  def notify_for_next_delivery(subscription)
    contact_properties = []

    custom_properties = []
    notify_subscriber(subscription, "subscription_order_reminder_email_id", contact_properties, custom_properties)
  end

  def notify_for_cc_expiration(subscription)
    contact_properties = []

    custom_properties = []
    notify_subscriber(subscription, "subscription_credit_card_expired_email_id", contact_properties, custom_properties)
  end

  def notify_for_oos(subscription)
    contact_properties = []

    custom_properties = []
    notify_subscriber(subscription, "subscription_out_of_stock_email_id", contact_properties, custom_properties)
  end

  def notify_for_placing_error(subscription)
    contact_properties = []

    custom_properties = []
    notify_subscriber(subscription, "subscription_generic_issue_email_id", contact_properties, custom_properties)
  end

  def notify_for_unpaused(subscription)
    contact_properties = []

    custom_properties = []
    notify_subscriber(subscription, "subscription_reactivated_email_id", contact_properties, custom_properties)
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

  def notify_subscriber(subscription, message_name, contact_properties, custom_properties)
    #byebug
    email_id=get_email_id(subscription, message_name)
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
