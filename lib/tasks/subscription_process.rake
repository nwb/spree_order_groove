namespace :subscription do
  desc "process all subscriptions whom orders are to be created"
  task process: :environment do |t, args|
    user_ids=Spree::Subscription.eligible_for_subscription.map(&:user_id)
    user_ids.each do |user_id|
      ss=Spree::Subscription.eligible_for_subscription.of_user(Spree::User.find(user_id))
      if ss.length>0
        if o=ss.last.recreate_order_for_subscriptions(ss)
          puts "Place auto delivery order for user #{user_id}, created order #{o.number} with state #{o.state}"
        else
          puts "Place auto delivery order for user #{user_id}, FAILED"
        end
      end
    end
  end
end
