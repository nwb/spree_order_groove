# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_order_groove'
  s.version     = '3.4.0'
  s.summary     = 'Order Groove provide the retain engine for ecommerce web sites, all customer sign up for auto delivery. This spree extension integrate it into spree'
  s.description = 'This extension works with classic Ordergroove server. There latest upgrade which needs Oath is not included'
  s.required_ruby_version = '>= 2.2.0'

  s.author    = 'Albert Liu'
  s.email     = 'albertliu@naturalwellbeing.com'
  s.homepage  = 'http://www.naturalwellbeing.com'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  version = '~> 3-4-stable'
  #s.add_dependency 'spree_core'
  s.add_dependency 'zip-zip'


end
