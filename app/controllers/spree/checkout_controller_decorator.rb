Spree::CheckoutController.class_eval do
  before_action :apply_autodelivery
  before_action :set_cc_number

  # this action is updated to post to orderGroove
  def update
    if @order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
      @order.temporary_address = !params[:save_user_address]
      unless @order.next
        flash[:error] = @order.errors.full_messages.join("\n")
        redirect_to checkout_state_path(@order.state) and return
      end

      if @order.completed?
        @current_order = nil
        flash.notice = Spree.t(:order_processed_successfully)
        flash['order_completed'] = true

        # this is the changes, if you find the spree version is different, copy this change to your version
        byebug
        og_autoship=cookies[:og_autoship]||0
        merchant_id= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_merchant_id"]
        hashkey= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_hashkey"]
        og_subscription_url= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_subscription_url_#{ENV["RAILS_ENV"]}"]

        if og_autoship.to_i==1

          rc4=RC4.new(hashkey)
          Rails.logger.error("*" * 50)
          Rails.logger.error("Order: " + @order.number + "subscribed to auto delivery, post to order groove now")
          Rails.logger.error("*" * 50)
          #encode the subscription
          subscription={:merchant_id =>merchant_id.to_s, :session_id=>cookies[:og_session_id], :merchant_order_id =>@order.number}
          billing_address=@order.bill_address
          subscription[:user]={:user_id=> @order.user_id.to_s, :first_name=>CGI.escape(billing_address.firstname), :last_name=>CGI.escape(billing_address.lastname), :email=>@order.checkout.email}
          subscription[:user][:billing_address]={:first_name=>CGI.escape(billing_address.firstname), :last_name=>CGI.escape(billing_address.lastname),:company_name=>"",:address=>CGI.escape(billing_address.address1),
                                                 :address2=>CGI.escape(billing_address.address2||''),:city=>CGI.escape(billing_address.city),:state_province_code=>(billing_address.state_id==nil ? billing_address.state_name : State.find(billing_address.state_id).abbr),:zip_postal_code=>billing_address.zipcode,:phone=>billing_address.phone,
                                                 :fax=>"",:country_code=>Country.find(billing_address.country_id).iso}
          billing_address=@order.ship_address
          subscription[:user][:shipping_address]={:first_name=>CGI.escape(billing_address.firstname), :last_name=>CGI.escape(billing_address.lastname),:company_name=>"",:address=>CGI.escape(billing_address.address1),
                                                  :address2=>CGI.escape(billing_address.address2||''),:city=>CGI.escape(billing_address.city),:state_province_code=>(billing_address.state_id==nil ? billing_address.state_name : State.find(billing_address.state_id).abbr),:zip_postal_code=>billing_address.zipcode,:phone=>billing_address.phone,
                                                  :fax=>"",:country_code=>Country.find(billing_address.country_id).iso}

          payment={:cc_holder=>CGI.escape(Base64.encode64(rc4.encrypt(billing_address.firstname + ' ' + billing_address.lastname)).chomp), :cc_type=>'1',:cc_number=> CGI.escape(session[:cc].chomp()),:cc_exp_date=>CGI.escape(Base64.encode64(rc4.encrypt(((@order.payments[0].source[:month].to_i<10 ? '0' : '') +@order.payments[0].source[:month] + '/' + @order.payments[0].source[:year]))).chomp) }
          subscription[:payment] =payment

        else
          subscription={:merchant_id =>merchant_id.to_s, :session_id=>cookies[:og_session_id]}
        end

        session[:cc] = ''

        # now post to orderGroove
        require "net/https"
        require "uri"
        #CheckoutsHelper.fetch("POST",og_subscription_url,'create_request='+ subscription.to_json )
        url=og_subscription_url
        method="POST"
        body= 'create_request='+ subscription.to_json
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
        rescue
          Rails.logger.error("Order: " + @order.number + "post to order groove fail")
        end


        redirect_to completion_route
      else
        redirect_to checkout_state_path(@order.state)
      end
    else
      render :edit
    end
  end

  private
  # remember the cc in session
  def set_cc_number
    # this is the changes, if you find the spree version is different, copy this change to your version


    if params[:state]=="payment" && params[:payment_source] && cookies[:og_autoship]
      hashkey= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_hashkey"]
      rc4=RC4.new(hashkey)
      session[:cc]  = Base64.encode64(rc4.encrypt(params[:payment_source].first.last[:number]))
    end

  end

end