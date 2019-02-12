module Spree
  class SubscriptionsController < Spree::BaseController

    before_action :ensure_subscription, except: [:index]
    before_action :ensure_not_cancelled, only: [:update, :cancel, :pause, :unpause]
    after_action :log_action, except: [:new_cc, :show, :index, :edit, :comments]
    #before_action :update_cc, only: [:update]


    def new_cc
      @credit_card=Spree::CreditCard.new
      render :credit_card, :layout => false
    end

    def new_cc_update
      #byebug
      payment_method=Spree::PaymentMethod.active.where("name like '%Credit Card%'").first
      source_attributes=params["subscription_source"].values
      source = payment_method.payment_source_class.new(params.require("subscription_source").permit(:name, :verification_value, :cc_type))
      source.expiry=params[:subscription_source]["expiry"]

      source.number= params[:subscription_source][:number]
      source.cc_type= source.try_type_from_number
      #@subscription.source.last_digits= nil
      source.payment_method_id = payment_method.id
      begin
        payment=Spree::Payment.create(:order_id=>@subscription.parent_order.id,
                                      :amount=>1.0,
                                      :payment_method_id=>payment_method.id
        )

        payment.source = source
        payment_method.create_profile(payment)  #authorize need profile before authorize
        res=payment_method.authorize(1, source, {})
      rescue e
        #flash[:error] = e.to_s
        payment.destroy if payment
        render :json => {"error" => e.to_s}.to_json
        #redirect_to(new_cc_admin_subscription_path(@subscription)) && return
        return
      end
      if res.success?
        #byebug
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
        #flash[:success] = t('.success')
        @credit_card = source
        render json: @credit_card.to_json
        #render '_payment_info', :layout => false
        return
        #redirect_to(edit_subscription_path(@subscription)) && return
      else
        #flash[:error] = t('.error')
        #render :text => "Error: Credit card information wrong, or rejected #{res.inspect}"
        render :json => {"error" => res.message}.to_json
        #render :text => "Error: Credit card information wrong, or rejected #{res.inspect}"
        return
        #redirect_to(new_cc_subscription_path(@subscription)) && return
      end
      #Rails.logger.info(params.inspect);
    end

    def edit
      @title="Subscription Edit"
    end
    def index
      @subscriptions = current_user.subscriptions #Spree::Subscription.joins("join spree_orders on spree_subscriptions.parent_order_id=spree_orders.id and spree_orders.user_id=", spree_current_user.id.to_s)
    end

    def update
      if @subscription.update(subscription_attributes)
        flash[:success] = 'Subscription updated successfully'
        respond_to do |format|
          format.html { redirect_to edit_subscription_path(@subscription), success: t('.success') }
          format.json { render json: { subscription: { price: @subscription.price, id: @subscription.id } }, status: 200 }
        end
      else
        respond_to do |format|
          format.html { render :edit }
          format.json { render json: { errors: @subscription.errors.full_messages.to_sentence }, status: 422 }
        end
      end
    end

    def cancel
      respond_to do |format|
        if @subscription.cancel
          format.json { render json: {
              subscription_id: @subscription.id,
              url: cancel_subscription_path(@subscription),
              flash: t(".success"),
              method: Spree::Subscription::ACTION_REPRESENTATIONS[:cancel].upcase
            }, status: 200
          }
          format.html { redirect_to edit_subscription_path(@subscription), success: t(".success") }
        else
          format.json { render json: {
              flash: t(".error")
            }, status: 422
          }
          format.html { redirect_to edit_subscription_path(@subscription), error: t(".error") }
        end
      end
    end

    def sendnow
      if @subscription.process
        order=@subscription.orders.last
        render json: {
            flash: t('.success'),
            url: order_path(order),
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

    def uncancel
      if @subscription.uncancel
        render json: {
            flash: t('.success', next_occurrence_at: @subscription.next_occurrence_at.to_date.to_formatted_s(:rfc822)),
            url: cancel_subscription_path(@subscription),
            button_text: Spree::Subscription::ACTION_REPRESENTATIONS[:cancel],
            next_occurrence_at: @subscription.next_occurrence_at.to_date,
            confirmation: Spree.t("subscriptions.confirm.cancel")
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

      def ensure_subscription
        if params[:id].include? "S"
        @subscription = Spree::Subscription.find_by_number(params[:id])
        else
          @subscription = Spree::Subscription.find(params[:id])
        end


        unless @subscription
          respond_to do |format|
            format.html { redirect_to account_path, error: Spree.t('subscriptions.alert.missing') }
            format.json { render json: { flash: Spree.t("subscriptions.alert.missing") }, status: 422 }
          end
        else
          unless spree_current_user && spree_current_user.id==@subscription.user_id
          respond_to do |format|
            format.html { redirect_to account_path, error: Spree.t('subscriptions.alert.missing') }
            format.json { render json: { flash: Spree.t("subscriptions.alert.missing") }, status: 422 }
          end
          end
        end
      end

      def ensure_not_cancelled
        if @subscription.not_changeable?
          respond_to do |format|
            format.html { redirect_back fallback_location: root_path, error: Spree.t("subscriptions.error.not_changeable") }
            format.json { render json: { flash: Spree.t("subscriptions.error.not_changeable") }, status: 422 }
          end
        end
      end

  end
end
