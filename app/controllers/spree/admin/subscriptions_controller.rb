module Spree
  module Admin
    class SubscriptionsController < Spree::Admin::ResourceController

      before_action :ensure_not_cancelled, only: [:update, :cancel, :cancellation, :pause, :unpause]

      def order_placing
        params[:q] = {} unless params[:q]
        params[:q][:place_status_cont] =""
        if params[:q][:placed_at_gt].blank?
          params[:q][:placed_at_gt] = Time.zone.now.beginning_of_day
        else
          params[:q][:placed_at_gt] = Time.zone.parse(params[:q][:placed_at_gt]).beginning_of_day rescue Time.zone.now.beginning_of_day
        end

        if params[:q] && !params[:q][:placed_at_lt].blank?
          params[:q][:placed_at_lt] = Time.zone.parse(params[:q][:placed_at_lt]).end_of_day rescue Time.zone.now.end_of_day
        end

        @sd = Time.parse(params[:q][:placed_at_gt].to_s).beginning_of_day rescue Time.now.beginning_of_day
        @ed = Time.parse( params[:q][:placed_at_lt].to_s).end_of_day rescue @sd.end_of_day

        if @sd > @ed
          @sd, @ed = @ed.beginning_of_day, @sd.end_of_day
        end
        
        @days_in_report = (@ed+1).to_date - @sd.to_date

        time_range = @sd..@ed
        #byebug
        @search=Spree::Subscription.search(params[:q])
        #@subscriptions = @search.result.page(params[:page]).per(30)
        @subscriptions=Spree::Subscription.where(:placed_at =>time_range ).page(params[:page]).per(30)

        #@search=Spree::Order.joins("join spree_orders_subscriptions on spree_orders_subscriptions.order_id = spree_orders.id join spree_subscriptions on spree_subscriptions.id = spree_orders_subscriptions.subscription_id").search(params[:q])
        #@autodelivery_orders = @search.result


      end

      def subscriptionsreport
        params[:q] = {} unless params[:q]
        @search=Spree::Subscription.search(params[:q])
        if params[:q][:completed_at_gt].blank?
          params[:q][:completed_at_gt] = Time.zone.now - 30.days
        else
          params[:q][:completed_at_gt] = Time.zone.parse(params[:q][:completed_at_gt]).beginning_of_day rescue Time.zone.now - 30.days
        end

        if !params[:q][:completed_at_lt].blank?
          params[:q][:completed_at_lt] = Time.zone.parse(params[:q][:completed_at_lt]).end_of_day rescue Time.zone.now
        else
          params[:q][:completed_at_lt] = Time.zone.now
        end

        @sd = Time.parse(params[:q][:completed_at_gt].to_s).beginning_of_day rescue Time.now.beginning_of_day
        @ed = Time.parse( params[:q][:completed_at_lt].to_s).end_of_day rescue @sd.end_of_day

        if @sd > @ed
          @sd, @ed = @ed.beginning_of_day, @sd.end_of_day
        end

        @days_in_report = (@ed+1).to_date - @sd.to_date

        time_range = @sd..@ed
        day_range=@sd.to_date..@ed.to_date


        @reports=[['Day', 'New Subscriptions', 'New Orders', 'Auto Delivered Orders']]
        day_range.each do |date|
          one_day_range=date.beginning_of_day..date.end_of_day
          subscriptions=Spree::Subscription.select("date(created_at) as ordered_date, number as new_subscriptions").where('spree_subscriptions.created_at' => one_day_range).length
          orders=Spree::Order.select("date(completed_at) as ordered_date, number as new_orders").where('spree_orders.completed_at' => one_day_range).length

          auto_delivered_orders=Spree::Order.select("date(completed_at) as ordered_date, number as auto_delivered_orders").where('spree_orders.channel' => 'order_groove', 'spree_orders.completed_at' => one_day_range).length

          @reports << [date.to_s, subscriptions, orders, auto_delivered_orders]
        end
        

      end

      
      def new_cc
         @credit_card=Spree::CreditCard.new
         render :credit_card
      end

      def new_cc_update
        #byebug
        payment_method=Spree::PaymentMethod.where("name like '%Credit Card%'").first
        source_attributes=params["subscription_source"].values
        source = payment_method.payment_source_class.new(params.require("subscription_source").permit(:name, :verification_value, :cc_type))
        source.expiry=params[:subscription_source]["expiry"]

        source.number= params[:subscription_source][:number]
        source.cc_type= @subscription.source.try_type_from_number
        #@subscription.source.last_digits= nil
        source.payment_method_id = payment_method.id
        begin
        res=payment_method.authorize(1, source, {})
        rescue e
          flash[:error] = e.to_s
          redirect_to(new_cc_admin_subscription_path(@subscription)) && return
        end
        if res.success?
          #byebug      
          @subscription.source=source
          #@subscription.source.gateway_customer_profile_id= nil
          payment_method.create_profile(@subscription)
          @subscription.source.save!
          @subscription.save!
          flash[:success] = t('.success')
          redirect_to(edit_admin_subscription_path(@subscription)) && return
        else
          flash[:error] = t('.error')
          redirect_to(new_cc_admin_subscription_path(@subscription)) && return
        end
         #Rails.logger.info(params.inspect);
      end

      def build_source
        if source_attributes.present? && source.blank? && payment_method.try(:payment_source_class)
          self.source = payment_method.payment_source_class.new(source_attributes)
          source.payment_method_id = payment_method.id
        end
      end

      def cancellation
      end

      def cancel
        if @subscription.cancel_with_reason(cancel_subscription_attributes)
          redirect_to collection_url, success: t('.success')
        else
          render :cancellation
        end
      end

      def pause
        if @subscription.pause
          render json: {
            flash: t('.success'),
            url: unpause_subscription_path(@subscription),
            button_text: Spree::Subscription::ACTION_REPRESENTATIONS[:unpause],
            confirmation: Spree.t("subscriptions.confirm.activate")
          }, status: 200
        else
          render json: {
            flash: t('.error')
          }, status: 422
        end
      end

      def sendnow
        if @subscription.process
          order=@subscription.orders.last
          render json: {
              flash: t('.success'),
              url: edit_subscription_path(@subscription),
              button_text: order.number,
              next_occurrence_at: @subscription.next_occurrence_at.to_date,
              confirmation: Spree.t("subscriptions.confirm.sendnow")
          }, status: 200
        else
          render json: {
              flash: t('.error')
          }, status: 422
        end
      end

      def unpause
        if @subscription.unpause
          render json: {
            flash: t('.success', next_occurrence_at: @subscription.next_occurrence_at.to_date.to_formatted_s(:rfc822)),
            url: pause_subscription_path(@subscription),
            button_text: Spree::Subscription::ACTION_REPRESENTATIONS[:pause],
            next_occurrence_at: @subscription.next_occurrence_at.to_date,
            confirmation: Spree.t("subscriptions.confirm.pause")
          }, status: 200
        else
          render json: {
            flash: t('.error')
          }, status: 422
        end
      end

      private

        def cancel_subscription_attributes
          params.require(:subscription).permit(:cancellation_reasons)
        end

        def collection
          @search = super.active.ransack(params[:q])
          @collection = @search.result.includes(:frequency, :complete_orders, variant: :product)
                                      .references(:complete_orders)
                                      .order(created_at: :desc)
                                      .page(params[:page])
        end

        def ensure_not_cancelled
          if @subscription.cancelled?
            redirect_to collection_url, error: Spree.t("admin.subscriptions.error_on_already_cancelled")
          end
        end

    end
  end
end
