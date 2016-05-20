Spree::Api::OrdersController.class_eval do

  skip_before_action :authenticate_user, only: :ogcreateorder
  skip_before_action :find_order, only: :ogcreateorder

  def ogcreateorder

    #****************************
    # linux shell call to this api
    # curl -X POST -H "Content-Type: text/xml" -d "@og_test1.xml" --header "X-Spree-Token: your_customers_user_key" local.naturalwellbeing.com:8080/api/orders/ogcreateorder
    # assume og_test1.xml should be in you current folder here.  X-Spree-Token is from spree_users

    #****************************

    og_logger ||= Logger.new("#{Rails.root}/log/og.log")
    # 0. get the RC4 Hash key
    merchant_id= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_merchant_id"]
    hashkey= Spree::OrdergrooveConfiguration.account["#{current_store.code}"]["og_hashkey"]
    rc4=RC4.new(hashkey)
    #begin
    # 1. parse xml (rails active support)
    #render :text => 'xml for orderOgId is: ' + params['order']['head']['orderOgId']

    # 2. check all parameters there
    # rails4 seems not recognizing xml as params
    string = request.body.read
    params = Hash.from_xml(string)

    errstr='parameter in OG xml is not complete'

    og_logger.info("#{Time.zone.at(Time.new()).strftime("%B %d, %Y at %I:%M PST")} :\n Start processing og dropped order: #{params.to_xml}")  # this xml is the re-generated one
    og_logger.info "#params.inspect"

    # 2.5 validate xml data ingrety
    strxml_error=''
    if params['order']['customer']['customerFirstName'].blank?
      strxml_error += 'customer first name blank,'
    end
    if params['order']['customer']['customerLastName'].blank?
      strxml_error += 'customer last name blank,'
    end
    if params['order']['customer']['customerShippingAddress1'].blank?
      strxml_error += 'customer shipping address blank,'
    end
    if params['order']['customer']['customerShippingCity'].blank?
      strxml_error += 'customer shipping city blank,'
    end
    if params['order']['customer']['customerShippingState'].blank?
      strxml_error += 'customer shipping state blank,'
    end
    if params['order']['customer']['customerShippingCountry'].blank?
      strxml_error += 'customer shipping country blank,'
    end
    if params['order']['customer']['customerShippingZip'].blank?
      strxml_error += 'customer shipping zip code blank,'
    end
    if params['order']['customer']['customerShippingPhone'].blank?
      strxml_error += 'customer shipping phone blank,'
    end

    if params['order']['customer']['customerBillingAddress1'].blank?
      strxml_error += 'customer Billing address blank,'
    end
    if params['order']['customer']['customerBillingCity'].blank?
      strxml_error += 'customer Billing city blank,'
    end
    if params['order']['customer']['customerBillingState'].blank?
      strxml_error += 'customer Billing state blank,'
    end
    if params['order']['customer']['customerBillingCountry'].blank?
      strxml_error += 'customer Billing country blank,'
    end
    if params['order']['customer']['customerBillingZip'].blank?
      strxml_error += 'customer Billing zip code blank,'
    end
    if params['order']['customer']['customerBillingPhone'].blank?
      strxml_error += 'customer Billing phone blank,'
    end
    if params['order']['customer']['customerPartnerId'].blank? && params['order']['customer']['customerEmail'].blank?
      strxml_error += 'customer customerEmail or customerPartnerId can not be both blank,'
    end
    if strxml_error.length>0
      render :xml =>'<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>130</errorCode><errorMsg>' + strxml_error + '</errorMsg></order>'
    else


      begin
      # 3. create order
      if params['order']['customer']['customerPartnerId'].blank?
        user=Spree::User.find_by_email(params['order']['customer']['customerEmail'])
      else
        user=Spree::User.find(params['order']['customer']['customerPartnerId'])
      end

      email=params['order']['customer']['customerEmail']
      if !user
        render :xml =>'<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>130</errorCode><errorMsg>User does not exist</errorMsg></order>'
      else

        order=user.orders.create(:store_id=>current_store.id,:channel => "order_groove", :item_total=>params['order']['head']['orderSubtotalValue'])

        #order.update_attribute(:user_id, user)  unless !user

        if Spree::State.find_by_abbr(params['order']['customer']['customerShippingState']).nil?
          shipstateid = ''
          shipstatename=params['order']['customer']['customerShippingState']
        else
          shipstateid = Spree::State.find_by_abbr(params['order']['customer']['customerShippingState']).id.to_s
          shipstatename=''
        end

        if (Spree::State.find_by_abbr(params['order']['customer']['customerBillingState']).nil?)
          billstateid=''
          billstatename=params['order']['customer']['customerBillingState']
        else
          billstateid = Spree::State.find_by_abbr(params['order']['customer']['customerBillingState']).id.to_s
          billstatename = ''
        end

        ship_address=Spree::Address.create(:firstname=>params['order']['customer']['customerFirstName'],
                                    :lastname=>params['order']['customer']['customerLastName'],
                                    :address1=>params['order']['customer']['customerShippingAddress1'],
                                    :address2=>params['order']['customer']['customerShippingAddress2'],
                                    :city=>params['order']['customer']['customerShippingCity'],
                                    :state_id=>shipstateid,
                                    :state_name=> shipstatename,
                                    :country_id=>Spree::Country.find_by_iso(params['order']['customer']['customerShippingCountry']).id.to_s||'',
                                    :zipcode=>params['order']['customer']['customerShippingZip'],
                                    :phone=>params['order']['customer']['customerShippingPhone']
        )
        ship_address.save!

        if params['order']['customer']['customerShippingCountry']=="US"
          bill_address=Spree::Address.create(:firstname=>params['order']['customer']['customerFirstName'],
                                      :lastname=>params['order']['customer']['customerLastName'],
                                      :address1=>params['order']['customer']['customerBillingAddress1'],
                                      :address2=>params['order']['customer']['customerBillingAddress2'],
                                      :city=>params['order']['customer']['customerBillingCity'],
                                      :state_id=>billstateid,
                                      :state_name=>billstatename,
                                      :country_id=>Spree::Country.find_by_iso(params['order']['customer']['customerBillingCountry']).id.to_s||'',
                                      :zipcode=>params['order']['customer']['customerBillingZip'],
                                      :phone=>params['order']['customer']['customerBillingPhone']
          )
        else
          bill_address=Spree::Address.create(:firstname=>params['order']['customer']['customerFirstName'],
                                      :lastname=>params['order']['customer']['customerLastName'],
                                      :address1=>params['order']['customer']['customerShippingAddress1'],
                                      :address2=>params['order']['customer']['customerShippingAddress2'],
                                      :city=>params['order']['customer']['customerShippingCity'],
                                      :state_id=>shipstateid,
                                      :state_name=> shipstatename,
                                      :country_id=>Spree::Country.find_by_iso(params['order']['customer']['customerShippingCountry']).id.to_s||'',
                                      :zipcode=>params['order']['customer']['customerShippingZip'],
                                      :phone=>params['order']['customer']['customerShippingPhone']
          )
        end

        bill_address.save!

        order.update_attributes(:email=>params['order']['customer']['customerEmail'], :ship_address_id=>ship_address.id, :bill_address_id=>bill_address.id) #, :shipping_method_id => shipping_method.id)

        order.shipments.each do |shipment|
          shipment.update_attributes(:address_id=>ship_address.id,:cost=>params['order']['head']['orderShipping'].to_f)
        end


        og_discount=[]
        if params['order']['items']['item'].class == Array
          items=params['order']['items']['item']
          else
          items=[params['order']['items']['item']]
        end



          items.each do |item|

            #byebug
            variant=Spree::Variant.find(item['product_id'].to_i)
            line_item=order.contents.add(
                variant,
                item['qty'].to_i || 1,
                {auto_delivery: true, price: item['price'], pre_tax_amount: item['finalPrice']}
            )
            #Spree::Adjustment.create(:order_id=>order.id, :amount=>item['discount'].to_f*(-1),:label =>'Auto Delivery Discount', :source_type => "Spree::PromotionAction", :adjustable_id => line_item.id, :adjustable_type => "Spree::LineItem") # discount


          end
         order.create_proposed_shipments

        order.line_items.each do |line_item|
            variant=Spree::Variant.find(line_item['variant_id'])
            if (variant.respond_to? :assembly) && variant.assembly?
              variant.parts.each do|v|
                line_item['quantity'].to_i.times {
                  v.count.to_i.times {
                    order.inventory_units.create(:variant_id=>v.id,:state=>'sold', :shipment_id=>order.shipments.first.id, :line_item_id=>line_item.id)
                  }
                }
              end
            else
              line_item['quantity'].to_i.times {
                order.inventory_units.create(:variant_id=>variant.id,:state=>'sold', :shipment_id=>order.shipments.first.id, :line_item_id=>line_item.id)
              }
            end
          end



        order.reload
        #order.update_totals
        order.total = params['order']['head']['orderTotalValue'].to_f
        #order.item_total = params['order']['head']['orderSubtotalValue'].to_f

        #shippings=order.adjustments.select{|a| a.source_type=="Spree::ShippingCharge"}

        #if params['order']['head']['orderShipping'].to_f == 0.00
          shipment=order.shipments.first
          rate = shipment.shipping_rates.select{|s| s[:selected]}.first || shipment.shipping_rates.first
          rate[:cost] = params['order']['head']['orderShipping'].to_f
          rate.save!
          order.set_shipments_cost
          # order.adjustments.select{|a| a.type=="ShippingCharge"}.first.destroy
        #end
        #order.line_items.each do |line_item|
        #Spree::Adjustment.create(:order_id=>order.id, :amount=>4.5*(-1),:label =>'Auto Delivery Discount', :source_type => "Spree::PromotionAction", :adjustable_id => line_item.id, :adjustable_type => "Spree::LineItem") # discount
        #end

        order.save!
        # to overwrite the possilbe tax update to 0, reset the total
        #order.total = params['order']['head']['orderTotalValue'].to_f

        # 4. payment
        if order.total > params['order']['head']['orderTotalValue'].to_f
          Spree::Adjustment.create(:order_id=>order.id, :amount=>(params['order']['head']['orderTotalValue'].to_f-order.total),:label =>'Auto Delivery Discount', :source_type => "Spree::PromotionAction", :adjustable_id => order.id, :adjustable_type => "Spree::Order") # discount

        end
        order.total=params['order']['head']['orderTotalValue'].to_f

        if params['order']['head']['orderPaymentMethod']== 'CC'
          payment_method=Spree::PaymentMethod.where(:name=>'Credit Card').first

          payment=Spree::Payment.create(:order_id=>order.id,
                                 :amount=>order.total,
                                 :payment_method_id=>payment_method.id
          )

          expire_date=rc4.decrypt(Base64.decode64(params['order']['head']['orderCcExpire'])).split('/')
          payment.source = payment_method.payment_source_class.new(:number=>rc4.decrypt(Base64.decode64(params['order']['head']['orderCcNumber'])),
                                                                   :month=>expire_date[0].to_i.to_s,
                                                                   :year=>expire_date[1],
                                                                   :verification_value=>213, #params['order']['head']['orderCcNumber'],
                                                                   :name=>params['order']['customer']['customerBillingFirstName'] +' '+params['order']['customer']['customerBillingLastName']
          )

          begin
            payment.source.number=rc4.decrypt(Base64.decode64(params['order']['head']['orderCcNumber']))
            payment_method.create_profile(payment)



            #payment.complete
            #payment.pend!
            payment.process!
            #order.process_payments!

            order.update_attributes({:state => "complete", :completed_at => Time.now})
            #order.update_attribute(:automated_approved_at, Time.now)
            until order.state == "complete"
              if order.next!
                order.update!
                #state_callback(:after)
              end
            end
            order.finalize!
            og_logger.info("og order is successfully created for #{email} in nwb with number: #{order.number}")
            result_xml='<?xml version="1.0" encoding="UTF-8"?><order><code>SUCCESS</code><orderId>' + order.number + '</orderId><errorMsg /></order>'
          rescue Spree::Core::GatewayError => ge
            # if it fails, destroy the payment and clear the autodelivery discount and flag
            payment.destroy
            order.destroy
            ge=ge.to_s
            error_code='140' #ge.params.messages.message.result_code
            if ge.include? ',,,,,,,,'    #this is raw of direct_response

              response_error_code=ge.split(',')[2]
              if %w(17).include? response_error_code
                error_code='100'
              elsif %w(6,28,37,78).include? response_error_code
                error_code='110'
              elsif %w(7,8).include? response_error_code
                error_code='120'
              elsif %w(27,127).include? response_error_code
                error_code='130'
              end
              error_message = ge.params['message'] || ge.params['response_reason_text'] || ge.message
            else
              error_message=ge #'' #ge.params.messages.message.text
            end

            if(error_code=='140' && error_message.include?('Please try again'))
              error_code='999'
            end
            og_logger.info("error happened in making the payment for #{email} with creditcard: #{ge}")
            result_xml='<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>' + error_code + '</errorCode><errorMsg>' + error_message + '</errorMsg></order>'
          rescue Exception => e
            error_code='999'
            og_logger.info("error happened in making the payment with errors for #{email} not from the gateway")
            result_xml='<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>' + error_code + '</errorCode><errorMsg>nwb side error</errorMsg></order>'
            external_key = Spree::BrontoConfiguration.account["nwb"]["NWB_operation"]
            Delayed::Job.enqueue( DelayedSimpleSend.new('nwb', "operations@naturalwellbeing.com", external_key, { :SENDTIME__CONTENT1 => "OG Place order Exception", :SENDTIME__CONTENT2 => "OG order placement for #{email} error, please check."},'html'), {priority: -10} )

          end
        else
          errstr="The payment method should be CC"
          og_logger.info("error happened in processing #{email} og order: #{errstr}")
          result_xml='<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>999</errorCode><errorMsg>' + errstr + '</errorMsg></order>'

          #raise(errstr)
        end

        # 5. response xml with code and message
        render :xml => result_xml #order.to_xml
      end
      rescue Exception => e
      error_code='130'
      og_logger.info("error happened in making the payment with errors for #{email} not from the gateway")
      result_xml='<?xml version="1.0" encoding="UTF-8"?><order><code>ERROR</code><errorCode>' + error_code + '</errorCode><errorMsg>' + e.to_s + '</errorMsg></order>'
      render :xml => result_xml #order.to_xml
    end
    end

  end

end
