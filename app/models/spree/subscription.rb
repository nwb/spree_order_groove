module Spree
  class Subscription < Spree::Base
    acts_as_commentable

    attr_accessor :cancelled

    include Spree::Core::NumberGenerator.new(prefix: 'S')

    ACTION_REPRESENTATIONS = {
                               pause: "Pause",
                               sendnow: "Sendnow",
                               unpause: "Activate",
                               cancel: "Cancel"
                             }

    USER_DEFAULT_CANCELLATION_REASON = "Cancelled By User"
    TRY_LIMIT = 3

    belongs_to :ship_address, class_name: "Spree::Address"
    belongs_to :bill_address, class_name: "Spree::Address"
    belongs_to :parent_order, class_name: "Spree::Order"
    belongs_to :user, class_name: "Spree::User"
    belongs_to :variant, inverse_of: :subscriptions
    belongs_to :frequency, foreign_key: :subscription_frequency_id, class_name: "Spree::SubscriptionFrequency"
    belongs_to :source, polymorphic: true

    accepts_nested_attributes_for :ship_address, :bill_address

    has_many :orders_subscriptions, class_name: "Spree::OrderSubscription", dependent: :destroy
    has_many :orders, through: :orders_subscriptions
    has_many :complete_orders, -> { complete }, through: :orders_subscriptions, source: :order

    self.whitelisted_ransackable_associations = %w( parent_order user )

    scope :paused, -> { where(paused: true) }
    scope :unpaused, -> { where(paused: false) }
    scope :disabled, -> { where(enabled: false) }
    scope :active, -> { where(enabled: true) }
    scope :not_cancelled, -> { where(cancelled_at: nil) }
    scope :can_try, -> {where("attempts<?", TRY_LIMIT)}
    scope :with_appropriate_delivery_time, -> { where("next_occurrence_at <= :current_date", current_date: Time.current) }
    scope :processable, -> { unpaused.active.not_cancelled.can_try }
    scope :eligible_for_subscription, -> { processable.with_appropriate_delivery_time }
    scope :of_user, -> (user) {where(user_id: user.id)}
    scope :with_parent_orders, -> (orders) { where(parent_order: orders) }
    scope :processed_between, ->(bday, eday) { where("placed_at>? and placed_at<?", bday, eday)}
    scope :with_error, -> { where("attempts>0")}

    with_options allow_blank: true do
      validates :price, numericality: { greater_than_or_equal_to: 0 }
      validates :quantity, numericality: { greater_than: 0, only_integer: true }
      #validates :delivery_number, numericality: { greater_than_or_equal_to: :recurring_orders_size, only_integer: true }
      validates :parent_order, uniqueness: { scope: :variant }
    end
    with_options presence: true do
      validates :user_id
      #validates :quantity, :delivery_number, :price, :number, :variant, :parent_order, :frequency
      validates :cancellation_reasons, :cancelled_at, if: :cancelled
      validates :ship_address, :bill_address, :next_occurrence_at, :source, if: :enabled?
    end
    validate :next_occurrence_at_range, if: :next_occurrence_at

    define_model_callbacks :pause, only: [:before]
    before_pause :can_pause?
    define_model_callbacks :unpause, only: [:before]
    before_unpause :can_unpause?, :set_next_occurrence_at_after_unpause
    define_model_callbacks :process, only: [:after]
    #after_process :notify_reoccurrence, if: :reoccurrence_notifiable?
    define_model_callbacks :cancel, only: [:before]
    before_cancel :set_cancellation_reason, if: :can_set_cancellation_reason?

    before_validation :set_next_occurrence_at, if: :can_set_next_occurrence_at?
    before_validation :set_cancelled_at, if: :can_set_cancelled_at?
    #before_update :not_cancelled?
    before_validation :update_price, on: :update, if: :variant_id_changed?
    before_update :next_occurrence_at_not_changed?, if: :paused?
    after_update :notify_user, if: :user_notifiable?
    after_update :notify_cancellation, if: :cancellation_notifiable?
    after_update :notify_uncancellation, if: :uncancellation_notifiable?

    def process
      new_order = recreate_order
      update(next_occurrence_at: next_occurrence_at_value) if new_order.try :completed?
    end

    def auto_delivery_price
      variant.volume_price(quantity,nil,parent_order.currency) + auto_delivery_discount
    end
    def auto_delivery_discount
      l=parent_order.line_items.where(variant: variant).first
      l.adjustments.eligible.where(label:"Promotion (Auto Delivery)").first["amount"] / l.quantity
    end

    def cancel_with_reason(attributes)
      self.cancelled = true
      update(attributes)
    end

    def cancelled?
      !!cancelled_at_was
    end

    def number_of_deliveries_left
      1000
    end

    def pause
      run_callbacks :pause do
        update_attributes(paused: true)
      end
    end

    def unpause
      run_callbacks :unpause do
        update_attributes(paused: false)
      end
    end

    def cancel
      self.cancelled = true
      run_callbacks :cancel do
        update_attributes(cancelled_at: Time.current)
      end
    end

    def uncancel
      run_callbacks :uncancel do
        update_attributes(cancelled_at: null, cancellation_reasons: "")
      end
    end

    def delivered_number
      recurring_orders_size
    end

    def deliveries_remaining?
      true
    end

    def not_changeable?
      cancelled?
    end

    def send_prior_notification
      if eligible_for_prior_notification?
        SubscriptionNotifier.notify_for_next_delivery(self).deliver_later
      end
    end

    def send_cc_expiration_notification
      if eligible_for_cc_expiration?
        SubscriptionNotifier.notify_for_cc_expiration(self).deliver_later
      end
    end

    def send_oos_notification
      if eligible_for_oos?
        SubscriptionNotifier.notify_for_oos(self).deliver_later
      end
    end

    def recreate_order_for_subscriptions subscriptions
      begin
        subscriptions, oos_subscriptions = subscriptions.partition{|p| p.variant.in_stock?}
        oos_subscriptions.each do|s|
           s.update_attributes(next_occurrence_at: Time.current.to_date + 15.days)
           s.send_oos_notification
        end
        if subscriptions.length==0
          return false
        end
        order = make_new_order
        add_variants_to_order(order, subscriptions)
        add_shipping_address(order)
        add_delivery_method_to_order(order)
        add_payment_method_to_order(order)
        order.payments.last.process!
        confirm_order(order)
        admin = Spree::Role.where(:name=>'admin').first.users.first
        subscriptions.each do |subscription|
          subscription.place_status =order.number
          subscription.next_occurrence_at= Time.current + subscription.frequency.weeks_count.week
          subscription.attempts=0
          subscription.save!
          subscription.comments.create(:title => "auto delivery order created", :comment => "Placed order #{order.number}", :user => admin)

        end
      rescue Spree::Core::GatewayError => ge
        subscriptions.each do |subscription|
          subscription.attempts =subscription.attempts+1
          subscription.place_status ="failed"
          subscription.last_error = ge.to_s
          SubscriptionNotifier.notify_for_placing_error(subscription).deliver_later
        end
      rescue Exception => e
        subscriptions.each do |subscription|
          subscription.attempts =subscription.attempts+1
          subscription.place_status ="failed"
          subscription.last_error = e.to_s
          SubscriptionNotifier.notify_for_placing_error(subscription).deliver_later
        end
      end
      subscriptions.each do |subscription|
        subscription.placed_at=Time.now()

        subscription.save!
      end
      order
    end
    
    private

      def eligible_for_prior_notification?
        (next_occurrence_at.to_date - Time.current.to_date).round == prior_notification_days_gap
      end

      def eligible_for_cc_expiration?
        cc=self.source
        cc_expire=Date.new(cc.year,cc.month)
        (cc_expire - Time.current.to_date).round < 33
      end

      def eligible_for_oos?
        variant.in_stock?
      end

      def update_price
        if valid_variant?
          self.price = variant.price
        else
          self.errors.add(:variant_id, :does_not_belong_to_product)
        end
      end

      def valid_variant?
        variant_was = Spree::Variant.find_by(id: variant_id_was)
        variant.present? && variant_was.try(:product_id) == variant.product_id
      end

      def set_cancelled_at
        self.cancelled_at = Time.current
      end

      def set_next_occurrence_at
        self.next_occurrence_at = next_occurrence_at_value
      end

      def next_occurrence_at_value
        Time.current + frequency.weeks_count.week
      end

      def can_set_next_occurrence_at?
        enabled? && next_occurrence_at.nil?
      end

      def set_next_occurrence_at_after_unpause
        self.next_occurrence_at = (Time.current > next_occurrence_at) ? Time.current + frequency.weeks_count.week : next_occurrence_at
      end

      def can_pause?
        enabled? && !cancelled? && !paused?
      end

      def can_unpause?
        enabled? && !cancelled? && paused?
      end

      def recreate_order
        begin
        order = make_new_order
        add_variant_to_order(order)
        add_shipping_address(order)
        add_delivery_method_to_order(order)
        add_payment_method_to_order(order)
        #order.next
        order.payments.last.process!
        #order.updater.update
        confirm_order(order)
        self.place_status =order.number
        self.attempts=0
        rescue Spree::Core::GatewayError => ge
          self.attempts =self.attempts+1
          self.place_status ="failed"
          self.last_error = ge.to_s
        rescue Exception => e
          self.attempts =self.attempts+1
          self.place_status ="failed"
          self.last_error = e.to_s
        end
        self.placed_at=Time.now()

        self.save!
        order
      end

      def make_new_order
        orders.create(order_attributes)
      end

      def add_variant_to_order(order)
        order.contents.add(variant, quantity, {auto_delivery: 1})
        order.next
      end

      def add_variants_to_order(order, subscriptions)
        subscriptions.each do |subscription|
          order.contents.add(subscription.variant, subscription.quantity, {auto_delivery: 1})
        end
        order.next
      end

      def add_shipping_address(order)
        order.ship_address = ship_address.clone
        order.bill_address = bill_address.clone
        order.next
      end

      def add_delivery_method_to_order(order)
        order.next
      end

      def add_payment_method_to_order(order)
        if order.payments.exists?
          order.payments.first.update(source: source, payment_method: source.payment_method)
        else
          order.payments.create(source: source, payment_method: source.payment_method, amount: order.total)
        end
      end

      def confirm_order(order)
        order.next
      end

      def order_attributes
        {
            channel: 'order_groove',
          currency: parent_order.currency,
          guest_token: parent_order.guest_token,
          store: parent_order.store,
          user_id: self.user_id,
          created_by: self.user
        }
      end

      def notify_user
        SubscriptionNotifier.notify_confirmation(self).deliver_later
      end

      def not_cancelled?
        !cancelled?
      end

      def can_set_cancelled_at?
        cancelled.present?
      end

      def set_cancellation_reason
        self.cancellation_reasons = USER_DEFAULT_CANCELLATION_REASON
      end

      def can_set_cancellation_reason?
        cancelled.present? && cancellation_reasons.nil?
      end

      def notify_cancellation
        SubscriptionNotifier.notify_cancellation(self).deliver_later
      end

      def notify_uncancellation
        SubscriptionNotifier.notify_uncancellation(self).deliver_later
      end

      def cancellation_notifiable?
        cancelled_at.present? && cancelled_at_changed?
      end

    def uncancellation_notifiable?
      !cancelled_at.present? && cancelled_at_changed?
    end

      def reoccurrence_notifiable?
        next_occurrence_at_changed? && !!next_occurrence_at_was
      end

      def notify_reoccurrence
        SubscriptionNotifier.notify_reoccurrence(self).deliver_later
      end

      def recurring_orders_size
        complete_orders.size + 1
      end

      def user_notifiable?
        enabled? && enabled_changed?
      end

      def next_occurrence_at_not_changed?
        !next_occurrence_at_changed?
      end

      def next_occurrence_at_range
        unless next_occurrence_at >= Time.current.to_date
          errors.add(:next_occurrence_at, Spree.t('subscriptions.error.out_of_range'))
        end
      end

  end
end
