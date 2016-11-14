require 'pp'
require 'net/sftp'
require 'tempfile'
require 'nokogiri'
require 'rubygems'
require 'zip/zip'
require 'stringio'
require 'uri'

desc "Set the environment variable RAILS_ENV='staging'."
task :staging do
  ENV["RAILS_ENV"] = 'staging'
  Rake::Task[:environment].invoke
end

namespace :spree do
  namespace :extensions do
    namespace :ordergroove do
      desc "upload og feeds"

      task :upload_prices => :environment do |t|
          start_time = Time.now
          report_str = [ "Uploading og feeds: #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"]
          success = true
          report_str << "Processing..."
          complete, report = upload_prices( start_time )
          report_str << report
          end_time = Time.now
          report_str << "Finished uploading og prices:  #{start_time.strftime( "%Y-%m-%d %H:%M:%S" )}"
          report_str << "Elapsed time: #{(end_time - start_time) rescue 'unknown'} seconds"
          puts report_str
      end

      def upload_prices  timestamp
        report = ""
        #sftp
        Spree::Store.all.each do |store|
          config=Spree::OrdergrooveConfiguration.account["#{store.code}"]
          Net::SFTP.start(config["og_ftp_host_#{ENV["RAILS_ENV"]}"], config["og_ftp_user"], :password => config["og_ftp_pass"]) do |sftp|
             # open and write to a pseudo-IO for a remote file

             report << "get the #{store.code} prices"
             file_content=get_html_content("https://#{store.url}/feed/ogdiscounts.csv")
             filename=config["og_merchant_id"] + ".BulkDiscount.csv"
             sftp.file.open(filename, "w") do |f|
                 report << "upload the #{store.code} prices"
                 f.puts file_content
             end
          end
        end

        result = true

        [result, report]
      end



      def get_html_content(requested_url)
        url = URI.parse(requested_url)
        full_path = (url.query.blank?) ? url.path : "#{url.path}?#{url.query}"
        the_request = Net::HTTP::Get.new(full_path)

        the_response = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') { |http|
          http.request(the_request)
        }

        raise "Response was not 200, response was #{the_response.code}" if the_response.code != "200"
        return the_response.body
      end

    end
  end
end

