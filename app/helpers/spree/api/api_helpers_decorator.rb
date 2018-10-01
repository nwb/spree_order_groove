Spree::Api::ApiHelpers.module_eval do
     # ATTRIBUTES <<:subscription_attributes

      @@subscription_attributes = [
          :id, :number,:subscription_frequency_id,:price, :variant,
          :quantity, :enabled, :next_occurrence_at, :prior_notification_days_gap
      ]

end
