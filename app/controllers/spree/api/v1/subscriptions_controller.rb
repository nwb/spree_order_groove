module Spree
  module Api
    module V1
      class SubscriptionsController < Spree::Api::BaseController
        before_action :find_subscription, except: [:index]

        def show
          respond_with(@subscription, default_template: :show)
        end

        def update
          byebug
          if @subscription.update_attributes(subscription_params)
            respond_with(@subscription, default_template: :show)
          else
            invalid_resource!(@subscription)
          end
        end

        private

        def subscription_params
          params.require(:subscription).permit([:quantity, :subscription_frequency_id, :prior_notification_days_gap,:next_occurrence_at,:paused, :enabled, :cancellation_reasons])
        end

        def address_params
          params.require(:address).permit(permitted_address_attributes)
        end

        def find_order
          @order = Spree::Order.find_by!(number: order_id)
        end

        def find_subscription
           @subscription = Spree::Subscription.joins("join spree_orders on spree_subscriptions.parent_order_id=spree_orders.id").where("spree_subscriptions.id=? and spree_orders.user_id=?", params[:id], current_spree_user.id.to_s)

        end
        def find_address
          if @order.bill_address_id == params[:id].to_i
            @order.bill_address
          elsif @order.ship_address_id == params[:id].to_i
            @order.ship_address
          else
            raise CanCan::AccessDenied
          end
        end
      end
    end
  end
end
