class AddUserIdToSubscription < SpreeExtension::Migration[4.2]
  def change
    add_column :spree_subscriptions, :user_id, :integer, null: false
  end
end
