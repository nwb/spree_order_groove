class RemoveFrequencyFromSpreeSubscriptions < SpreeExtension::Migration[4.2]
  def change
    remove_column :spree_subscriptions, :frequency, :string
  end
end
