class AddAttemptToSubscription < SpreeExtension::Migration[4.2]
  def change
    add_column :spree_subscriptions, :attempts, :integer, default: 0
    add_column :spree_subscriptions, :placed_at, :date
    add_column :spree_subscriptions, :place_status, :string
    add_column :spree_subscriptions, :failed_at, :date
    add_column :spree_subscriptions, :last_error, :text
  end
end
