require 'rack/test'
require 'rspec'

ENV['RACK_ENV'] = 'test'
puts Dir.pwd
require './vcloud.rb'

module RSpecMixin
  include Rack::Test::Methods
  def app() VCloudStats end
end

RSpec.configure { |c| c.include RSpecMixin }

