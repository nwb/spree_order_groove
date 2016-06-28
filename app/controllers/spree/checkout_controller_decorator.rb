Spree::CheckoutController.class_eval do
  #before_action :apply_autodelivery
  before_action :set_cc_number
  before_action :create_autodelivery_user
  after_action :create_autodelivery_order

  # this action is to post to orderGroove
  def create_autodelivery_order
      if @order.completed?

        #if og_autoship.to_i==1
        if Spree::Promotion::Rules::Autodelivery.new.eligible?(@order) && !!@order.user  # if this order is ready to signup
          merchant_id= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_merchant_id"]
          hashkey= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_hashkey"]
          og_subscription_url= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_subscription_url_#{ENV["RAILS_ENV"]}"]
          og_offer_id= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_offer_id"]

          rc4=RC4.new(hashkey)
          Rails.logger.error("*" * 50)
          Rails.logger.error("Order: " + @order.number + " subscribed to auto delivery, post to order groove now")
          Rails.logger.error("*" * 50)
          #encode the subscription
          subscription={:offer_id =>og_offer_id, :session_id=>cookies[:og_session_id]||"", :order_number =>@order.number}
          billing_address=@order.bill_address
          customer={:id=> @order.user_id.to_s, :first_name=>(billing_address.firstname), :last_name=>(billing_address.lastname), :email=>@order.email}
          customer[:billing_address]={:first_name=>(billing_address.firstname), :last_name=>(billing_address.lastname),:company_name=>"",:address=>(billing_address.address1),
                                                 :address2=>(billing_address.address2||''),:city=>(billing_address.city),:state=>(billing_address.state_id==nil ? billing_address.state_name : Spree::State.find(billing_address.state_id).abbr),:zip_code=>billing_address.zipcode,:phone=>billing_address.phone,
                                                 :fax=>"",:country_code=>Spree::Country.find(billing_address.country_id).iso}
          billing_address=@order.ship_address
          customer[:shipping_address]={:first_name=>(billing_address.firstname), :last_name=>(billing_address.lastname),:company_name=>"",:address=>(billing_address.address1),
                                                  :address2=>(billing_address.address2||''),:city=>(billing_address.city),:state=>(billing_address.state_id==nil ? billing_address.state_name : Spree::State.find(billing_address.state_id).abbr),:zip_code=>billing_address.zipcode,:phone=>billing_address.phone,
                                                  :fax=>"",:country_code=>Spree::Country.find(billing_address.country_id).iso}

          payment={:cc_holder=>Base64.encode64(rc4.encrypt(billing_address.firstname + ' ' + billing_address.lastname)).chomp, :cc_type=>'visa',:cc_number=> session[:cc].chomp(),:cc_exp_date=>Base64.encode64(rc4.encrypt(((@order.payments.last.source[:month].to_i<10 ? '0' : '') +@order.payments.last.source[:month] + '/' + @order.payments.last.source[:year]))).chomp }

          customer[:payment] =payment
          subscription[:customer] =customer

          subscriptions=[]
          @order.line_items.select{|l| l.auto_delivery}.each do |line_item|
            subscriptions << {:product_id => line_item.variant_id,
              :qty =>line_item.quantity,
               :frequency => line_item.frequency.gsub('_2',''),
                :period=>"week" }

            # post only one product one time
            #byebug
            begin
              subscription[:offer_id] =line_item.adjustments.eligible.select{|a| a.label.include? 'Auto'}.first.source.promotion.description
              subscription[:subscriptions] =subscriptions
              post_subscription subscription
            rescue
              subscriptions=[]
            end
            subscriptions=[]

          end

          #subscription[:subscriptions] =subscriptions

          session[:cc] = ''


          #post_subscription subscription
        end
      end
  end

  private
  # the post creation to orderGroove
  def post_subscription subscription
    # now post to orderGroove
    require "net/https"
    require "uri"
    #CheckoutsHelper.fetch("POST",og_subscription_url,'create_request='+ subscription.to_json )
    url= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_subscription_url_#{ENV["RAILS_ENV"]}"]
    Rails.logger.error("data object to be posed:\n #{subscription.inspect}")
    body= subscription.to_json
    headers={}
    headers["Content-Type"] = 'application/json' unless body.nil?
    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 2
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body=body

      response = http.request(request)
      Rails.logger.error("post to orderGroove response:\n #{response.body.to_yaml}")

      result=JSON.parse(response.body)
       #{"subscriptions"=>{"1805"=>"779cd240cb6c11e599a3bc764e106cf4"}, "error"=>{}, "request_id"=>"56b397bfb3ade34c37783f96"}
      Rails.logger.error("Subscription is created: #{result["subscriptions"]}")
      if result["error"].blank?
        Rails.logger.error("Subscription creation failed with error: #{result["error"]}")
      end

      Rails.logger.error("Order: " + @order.number + " auto delivery is created in order groove.\nthe post body is: \n" + subscription.to_json)
    rescue
      Rails.logger.error("Order: " + @order.number + " post to order groove fail\n the post body is: \n" + subscription.to_json)
    end
  end

  #if the user password appear in checkout params, create user
  def create_autodelivery_user
    if params[:state]=="address" && params[:spree_user]
      begin
        #byebug
        params[:spree_user][:email]=params[:order][:email]
        @user=Spree::User.new(params.require(:spree_user).permit(Spree::PermittedAttributes.user_attributes))
        if @user.save
          flash[:notice] = Spree.t(:signed_up)
          if current_order
            current_order.associate_user! @user
          end
          sign_in(:spree_user, @user)
          session[:spree_user_signup] = true
        else
          clean_up_passwords(@user)
        end
      rescue
        flash[:error] = @user.errors.full_messages.join("\n")
        redirect_to checkout_state_path(@order.state) and return
      end
    end
  end

  # remember the cc in session
  def set_cc_number
    # this is the changes, if you find the spree version is different, copy this change to your version


    if params[:state]=="payment" && params[:payment_source] && Spree::Promotion::Rules::Autodelivery.new.eligible?(@order)
      hashkey= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_hashkey"]
      rc4=RC4.new(hashkey)
      session[:cc]  = Base64.encode64(rc4.encrypt(params[:payment_source].first.last[:number]))
    end

  end

end