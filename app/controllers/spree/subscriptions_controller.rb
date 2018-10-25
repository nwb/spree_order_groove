module Spree
  class SubscriptionsController < Spree::BaseController

    before_action :ensure_subscription, except: [:index]
    before_action :ensure_not_cancelled, only: [:update, :cancel, :pause, :unpause]

    #before_action :update_cc, only: [:update]


    def new_cc
      @credit_card=Spree::CreditCard.new
      render :credit_card, :layout => false
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
        #flash[:error] = e.to_s
        render :json => {"error" => e.to_s}.to_json
        #redirect_to(new_cc_admin_subscription_path(@subscription)) && return
        return
      end
      if res.success?
        #byebug
        @subscription.source=source
        #@subscription.source.gateway_customer_profile_id= nil
        payment_method.create_profile(@subscription)
        @subscription.source.save!
        @subscription.update_attributes(source: source, attempts:0)
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
    end
    def index
      @subscriptions = Spree::Subscription.joins("join spree_orders on spree_subscriptions.parent_order_id=spree_orders.id and spree_orders.user_id=", spree_current_user.id.to_s)
    end

    def update
      if @subscription.update(subscription_attributes)
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
