# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_order_groove'
  s.version     = '3.0.0'
  s.summary     = 'Order Groove provide the retain engine for ecommerce web sites, all customer sign up for auto delivery. This spree extension integrate it into spree'
  s.description = 'This extension works with classic Ordergroove server. There latest upgrade which needs Oath is not included'
  s.required_ruby_version = '>= 2.0.0'

  s.author    = 'Albert Liu'
  s.email     = 'albertliu@naturalwellbeing.com'
  s.homepage  = 'http://www.naturalwellbeing.com'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  version = '~> 3-0-stable'
  #s.add_dependency 'spree_core'

  s.add_development_dependency 'capybara', '~> 2.4'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl', '~> 4.5'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails',  '~> 3.1'
  s.add_development_dependency 'sass-rails', '~> 5.0.0.beta1'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
end
