module Spree
  module Admin
    class SubscriptionsController < Spree::Admin::ResourceController

      before_action :ensure_not_cancelled, only: [:update, :cancel, :cancellation, :pause, :unpause]
      after_action :log_action, except: [:new_cc, :show, :index, :edit, :order_placing, :subscriptionsreport, :build_source, :comments]
      
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

      def edit
        @title="Subscription Edit"
      end

      def update
        if @subscription.update(subscription_attributes)
          flash[:success] = 'Subscription updated successfully'
          respond_to do |format|
            format.html { redirect_to edit_admin_subscription_path(@subscription), success: t('.success') }
            format.json { render json: { subscription: { price: @subscription.price, id: @subscription.id } }, status: 200 }
          end
        else
          respond_to do |format|
            format.html { edit_admin_subscription_path(@subscription) }
            format.json { render json: { errors: @subscription.errors.full_messages.to_sentence }, status: 422 }
          end
        end
      end

      def new_cc
         @credit_card=Spree::CreditCard.new
         render :credit_card
      end

      def new_cc_update
        #byebug
        payment_method=Spree::PaymentMethod.active.where("name like '%Credit Card%'").first
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
          payment=Spree::Payment.create(:order_id=>@subscription.parent_order.id,
                                        :amount=>1.0,
                                        :payment_method_id=>payment_method.id
          )

          payment.source = source
          payment_method.create_profile(payment)
          payment.source.save!

          if params["apply_to_all"]
            user= @subscription.user
            subscriptions=user.subscriptions
            subscriptions.each do |subscription|
              subscription.source= payment.source
              subscription.update_attributes(source: source, attempts:0)
            end
          else
            @subscription.source= payment.source
            @subscription.update_attributes(source: source, attempts:0)
          end

          payment.destroy
          
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
              url: edit_admin_order_path(order),
              button_text: order.number,
              to_link: true,
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
      def log_action
        begin
          if action_name=="update"
            @subscription.comments.create(:title => "#{action_name} requested", :comment => "Sent #{action_name.upcase} to server with result:  #{sub_data}", :user => spree_current_user)
          elsif action_name=="new_cc_update"
            @subscription.comments.create(:title => "#{action_name} requested", :comment => "Sent #{action_name.upcase} to server with cc:  #{@subscription.source.last_digits}", :user => spree_current_user)
          else
            @subscription.comments.create(:title => "#{action_name} requested", :comment => "Sent #{action_name.upcase} to server", :user => spree_current_user)
          end
        rescue
          #should we do more here. should be no error raised for this log.
        end
      end

      def sub_data
        changes=""
        changes +=" frequency: "+ @subscription.subscription_frequency_id.to_s
        changes +=" quantity: "+ @subscription.quantity.to_s
        changes +=" <br>notification_days_gap: "+ @subscription.prior_notification_days_gap.to_s
        changes +=" next order date: "+ @subscription.next_occurrence_at.to_date.to_s
        changes +=" <br>ship address: "+ @subscription.ship_address.address1+ " "+ @subscription.ship_address.city + " " + @subscription.ship_address.zipcode.to_s
        changes
      end

      def subscription_attributes
        params.require(:subscription).permit(:quantity, :next_occurrence_at,
                                             :subscription_frequency_id, :variant_id, :prior_notification_days_gap,
                                             ship_address_attributes: [:firstname, :lastname, :address1, :address2, :city, :zipcode, :country_id, :state_id, :phone],
                                             bill_address_attributes: [:firstname, :lastname, :address1, :address2, :city, :zipcode, :country_id, :state_id, :phone])
      end
      
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
