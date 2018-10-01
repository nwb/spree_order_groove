class AddMonthsCountColumnToSpreeSubscriptionFrequencies < SpreeExtension::Migration[4.2]
  def change
    add_column :spree_subscription_frequencies, :weeks_count, :integer
  end
end
