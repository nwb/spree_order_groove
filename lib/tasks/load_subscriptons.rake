require 'pp'
require 'net/sftp'
require 'tempfile'
require 'rc4'
require 'nokogiri'
require 'rubygems'
require 'zip/zip'
require 'stringio'
require 'uri'

namespace :subscription do
      desc "upload og products"
      task :load_order_groove_data, [:file, :store_code] => :environment do |t, args|
        store_code= args[:store_code]

        #byebug
        #config=Spree::OrdergrooveConfiguration.account["#{store_code}"]

        file_name=args[:file]
        start_time = Time.now
        report_str = [ "process file #{file_name}: #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"]
        success = true
        #csv_text=File.read(file_name)

        #tfile=File.open(Rails.root.join(file_name.gsub('.csv','') + '_tmp.csv'), "w")
        file = File.open(Rails.root.join(file_name))


        #csv_text = File.read(Rails.root.join(file_name)
        csv = CSV.parse(File.read(file), :headers => true, :col_sep =>"|", :encoding => 'bom|utf-8')
        #"Subscription Status""","Next Order Date","Originating Order ID","Merchant Customer ID","Email Address","First Name","Last Name","Product","Product ID","SKU",
        # "Frequency Every","Frequency Period","Quantity","CC Holder","CC Number","CC Type","CC Expiration Date",
        # "Billing First","Billing Last","Billing Address 1","Billing Address 2","Billing City","Billing State","Billing Zip","Billing Company","Billing Country","Billing Phone","Billing Fax",
        # "Shipping First","Shipping Last","Shipping Address 1","Shipping Address 2","Shipping City","Shipping State","Shipping Zip","Shipping Company","Shipping Country","Shipping Phone","Shipping Fax",
        # "Subscription Start Date","Subscription Create Date","Subscription Cancel Date","Order Counter","Public Offer ID","Subscription Extra Data","Subscription ID"
        csv.each do |row|
          #byebug
          unless row['Subscription Status']=="True"
            next
          end
          if !row['Merchant Customer ID']
            puts "subscription " + row["Subscription ID"] + " no user data available in spree, ignored!"
            next
          end
          user=Spree::User.find(row['Merchant Customer ID'])
          parent_order = Spree::Order.find_by_number(row['Originating Order ID'])
          if !user
            puts "subscription " + row["Subscription ID"] + " no user data available in spree, ignored!"
            next
          end
          if !parent_order && user.orders.length==0
            puts "subscription " + row["Subscription ID"] + " no order data available in spree, ignored!"
            next
          end

          if !parent_order
            parent_order=user.orders.complete.last
          end
          if !parent_order
            next
          end
          
          last_order = user.orders.complete.where(channel: 'order_groove').last
          last_order = parent_order unless last_order

          next if last_order && last_order.completed_at< Time.zone.now-25.weeks

          begin
            #byebug
            subscription_attributes= subscription_attributes_from_row(row, last_order, parent_order,store_code)

            unless !row["Subscription Cancel Date"]
              subscription_attributes[:cancelled_at]=Time.new(row["Subscription Cancel Date"])
              subscription_attributes[:cancellation_reasons] ="cancelled by customer in orderGroove"
            end
          subscription=user.subscriptions.create(subscription_attributes)
          if !subscription
            puts "FAILED in creating subscription"
            log_process_error(row)
            next
          end
          subscription.update_attribute(:created_at, row["Subscription Create Date"])
          subscription.update_attribute(:price, subscription.auto_delivery_price)
          unless last_order==parent_order
            subscription.update_attribute(:place_status, last_order.number)
            subscription.update_attribute(:placed_at, last_order.completed_at)
          end
          #check any placed orders
          user.orders.where(channel: 'order_groove').each do |order|
            #byebug
            subscription.orders<< order
          end
          report_str << "created subscription #{subscription.number} for subscritpion from orderGoove: #{row["Subscription ID"]}"
          report_str << "but the credit card information is invalid." unless  subscription.source
            #user.create_song_with_tags row['song'], row['tags']
          rescue Exception => ex
            log_process_error(row)
            puts "\n " + row["Subscription ID"] + " failed being created with error:"
            puts "" + ex.to_s
          end
        end

        report_str << "Processing..."
        end_time = Time.now
        report_str << "Finished processing file #{file_name}:  #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"
        report_str << "Elapsed time: #{(end_time - start_time) rescue 'unknown'} seconds"
        puts report_str
      end

      def log_process_error(row)
         if row['Subscription Status']=="True"
           puts ""
           puts "*" * 50
           puts "ACTIVE subscription " + row["Subscription ID"] + " failed in migration, please handle it manually"
           puts row.to_s
           puts "*" * 50
           puts ""
         else
           puts "subscription " + row["Subscription ID"] + " failed in migration."
         end

      end
      def  subscription_attributes_from_row row, last_order, parent_order, store_code
        source=get_payment_source(row, last_order, store_code)
        {paused:(row['Subscription Status']=="True" ? 0 : 1),
          bill_address: get_bill_address_from_row(row),
          ship_address: get_ship_address_from_row(row),
          variant_id: row['Product ID'],
          quantity: row['Quantity'],
          parent_order_id: parent_order.id,
          subscription_frequency_id: row['Frequency Every'].to_i,
          enabled: 1,
          prior_notification_days_gap: 10,
          attempts: 2,
          next_occurrence_at: row['Next Order Date'],
          source: source
        }
      end

      def get_payment_source row, last_order, store_code
        hashkey= Spree::OrdergrooveConfiguration.account[store_code]["og_hashkey"]
        rc4=RC4.new(hashkey)
        if last_order.payments.completed.length>0
          last_source=last_order.payments.completed.first.source
        end
        expire_date=rc4.decrypt(Base64.decode64(row["CC Expiration Date"])).split('/')
        #if the same card just return
        #byebug
        if last_source && last_source.class=="CreditCard" && last_source.month==expire_date[0].to_i && last_source.year==expire_date[1].to_i
          return last_source
        end
          # "CC Holder","CC Number","CC Type","CC Expiration Date",
        #create the new cc after authorization
        payment_method=Spree::PaymentMethod.active.where("name like '%Credit Card%'").last
        source = payment_method.payment_source_class.new(:number=>rc4.decrypt(Base64.decode64(row['CC Number'])),
                                                         :month=>expire_date[0].to_i.to_s,
                                                         :year=>expire_date[1],
                                                         :payment_method_id=>payment_method.id,
                                                         #:verification_value=>213, #params['order']['head']['orderCcNumber'],
                                                         :name=>row['Billing First'] +' '+row['Billing Last']
        )

        source.cc_type= source.try_type_from_number
        begin
          payment=Spree::Payment.create(:order_id=>last_order.id,
                                        :amount=>1.0,
                                        :payment_method_id=>payment_method.id
          )

          payment.source = source
          payment_method.create_profile(payment)
          res=payment_method.authorize(1, source, {})
        rescue Exception =>e
          payment.destroy if payment
          puts "failed adding credit card: #{e.to_s}"
          return nil
        end
        if res.success?
          payment.source.save!
          source= payment.source
          payment.destroy
          source
        else
          last_source
        end
      end

      def  get_ship_address_from_row row
        if (Spree::State.find_by_abbr(row['Shipping State']).nil?)
          billstateid=''
          billstatename=row['Shipping State']
        else
          billstateid = Spree::State.find_by_abbr(row['Shipping State']).id.to_s
          billstatename = ''
        end
         ship_address=Spree::Address.create(:firstname=>row['Shipping First'],
                                           :lastname=>row['Shipping Last'],
                                           :address1=>(row['Shipping Address 1'] || '').gsub('comma',','),
                                           :address2=>(row['Shipping Address 2'] || '').gsub('comma',','),
                                           :city=>row['Shipping City'],
                                           :state_id=>billstateid,
                                           :state_name=> billstatename,
                                           :country_id=>Spree::Country.find_by_iso(row['Shipping Country']).id.to_s||'',
                                           :zipcode=>row['Shipping Zip'],
                                           :phone=>row['Shipping Phone'])
        ship_address
      end

      def  get_bill_address_from_row row
        if (Spree::State.find_by_abbr(row['Billing State']).nil?)
          billstateid=''
          billstatename=row['Billing State']
        else
          billstateid = Spree::State.find_by_abbr(row['Billing State']).id.to_s
          billstatename = ''
        end
        ship_address=Spree::Address.create(:firstname=>row['Billing First'],
                                           :lastname=>row['Billing Last'],
                                           :address1=>(row['Billing Address 1'] || '').gsub('comma',','),
                                           :address2=>(row['Billing Address 2'] || '').gsub('comma',','),
                                           :city=>row['Billing City'],
                                           :state_id=>billstateid,
                                           :state_name=> billstatename,
                                           :country_id=>Spree::Country.find_by_iso(row['Billing Country']).id.to_s||'',
                                           :zipcode=>row['Billing Zip'],
                                           :phone=>row['Billing Phone'])
        ship_address
      end
end


