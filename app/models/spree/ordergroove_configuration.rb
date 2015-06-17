module Spree
  class OrdergrooveConfiguration

    def self.account
      bronto_yml=File.join(Rails.root,'config/ordergroove.yml')
      if File.exist? bronto_yml
        bronto_yml=File.join(Rails.root,'config/ordergroove.yml')
        YAML.load(File.read(bronto_yml))
      end
    end
  end
end