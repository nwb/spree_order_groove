class RemoveEndDateFromSubscriptions < SpreeExtension::Migration[4.2]
  def change
    remove_column :spree_subscriptions, :end_date, :datetime
  end
end
