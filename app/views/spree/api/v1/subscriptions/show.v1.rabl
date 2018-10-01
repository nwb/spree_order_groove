object @subscription
cache [I18n.locale, root_object]
attributes *[id:, :number,:subscription_frequency_id,:price, :variant, :quantity, :enabled, :next_occurrence_at, :prior_notification_days_gap ]

child(:bill_address) do |_subscription|
  attributes *address_attributes
end
child(:source) do |_subscription|
  attributes *creditcard_attributes
end
