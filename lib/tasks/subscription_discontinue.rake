namespace :subscription do
  desc "process all subscriptions whom orders are to be created"
  task discontinue: :environment do |t, args|
    dis_products=Spree::Product.where("discontinue_on > ? and discontinue_on< ?", Time.now-1.day,Time.now)
    dis_products.each do |product|
      product.variants.each do |variant|
        variant.subscriptions.each do |subscription|
          subscription.cancel_with_reason(:cancellation_reasons => "Product discontinued.")
          puts "Cancel subscription because of product discontinued: #{subscription.number}"
        end
      end
    end
  end
end
