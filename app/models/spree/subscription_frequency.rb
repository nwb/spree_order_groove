module Spree
  class SubscriptionFrequency < Spree::Base

    has_many :product_subscription_frequencies, class_name: "Spree::ProductSubscriptionFrequency",
                                                dependent: :destroy
    has_many :subscriptions, class_name: "Spree::Subscription", dependent: :restrict_with_error

    validates :title, :weeks_count, presence: true
    with_options allow_blank: true do
      validates :weeks_count, numericality: { greater_than: 0, only_integer: true }
      validates :title, uniqueness: { case_sensitive: false }
    end

    def every_title
      "Every " + title
    end
  end
end
