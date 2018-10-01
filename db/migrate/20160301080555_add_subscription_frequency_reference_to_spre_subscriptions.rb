class AddSubscriptionFrequencyReferenceToSpreSubscriptions < SpreeExtension::Migration[4.2]
  def change
    add_reference :spree_subscriptions, :subscription_frequency, index: true
  end
end
