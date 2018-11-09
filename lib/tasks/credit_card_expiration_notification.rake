namespace :subscription do
  desc "remid customer credit card expiring"
  task cc_expiration_notify: :environment do |t, args|
    Spree::Subscription.active.find_in_batches do |batches|
      batches.map(&:send_cc_expiration_notification)
    end
  end
end
