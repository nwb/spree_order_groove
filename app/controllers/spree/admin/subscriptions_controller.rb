module Spree
  module Admin
    class SubscriptionsController < Spree::Admin::ResourceController

      before_action :ensure_not_cancelled, only: [:update, :cancel, :cancellation, :pause, :unpause]
      #before_action :update_cc, only: [:update]


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
