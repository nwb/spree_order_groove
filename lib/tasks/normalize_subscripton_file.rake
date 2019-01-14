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
      task :normalize, [:file, :store_code] => :environment do |t, args|
        store_code= args[:store_code]

        #byebug
        #config=Spree::OrdergrooveConfiguration.account["#{store_code}"]

        file_name=args[:file]
        start_time = Time.now
        report_str = [ "process file #{file_name}: #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"]
        success = true
        #csv_text=File.read(file_name)

        tfile=File.open(Rails.root.join(file_name.gsub('.csv','') + '_tmp.csv'), "w")
        file = File.open(Rails.root.join(file_name))
        file.each do |line|
          #puts line

          tfile << line.gsub("\"\"\"","\"").gsub(/\"\,\"/,"|").gsub(/,,/,"||").gsub("\"\"","\"").gsub('"','') #.gsub!(/\!/, "")  #if line.include? "True"
          begin
            #csv=CSV.parse_line(line)
          rescue Exception => e
            puts "Error: " + e.to_s
            puts line.split(",").join("    ")
          end

          #puts line unless csv.length==51
        end


        #csv_text = File.read(Rails.root.join(file_name)
        #csv = CSV.parse(File.read(tfile), :headers => true, :encoding => 'utf-8')
        #"Subscription Status""","Next Order Date","Originating Order ID","Merchant Customer ID","Email Address","First Name","Last Name","Product","Product ID","SKU",
        # "Frequency Every","Frequency Period","Quantity","CC Holder","CC Number","CC Type","CC Expiration Date",
        # "Billing First","Billing Last","Billing Address 1","Billing Address 2","Billing City","Billing State","Billing Zip","Billing Company","Billing Country","Billing Phone","Billing Fax",
        # "Shipping First","Shipping Last","Shipping Address 1","Shipping Address 2","Shipping City","Shipping State","Shipping Zip","Shipping Company","Shipping Country","Shipping Phone","Shipping Fax",
        # "Subscription Start Date","Subscription Create Date","Subscription Cancel Date","Order Counter","Public Offer ID","Subscription Extra Data","Subscription ID"
        

        report_str << "Normalizing..."
        end_time = Time.now
        report_str << "Finished processing file #{file_name}:  #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"
        report_str << "Elapsed time: #{(end_time - start_time) rescue 'unknown'} seconds"
        puts report_str
      end


end


