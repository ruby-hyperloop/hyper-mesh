# /spec-opal/spec_helper.js.rb
#require 'components'
require 'my_lib'
#require 'support/some_spec_helper'

RSpec.configure do |config|
  config.before(:all) { puts "before all hook"}
  #config.include SomeSpecHelper
end
