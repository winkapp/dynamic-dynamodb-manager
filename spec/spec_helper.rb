$: << File.join(File.dirname(__FILE__), '/../lib' )

require 'rubygems'
require 'bundler'
require 'rspec'
require 'rack/test'
require 'webmock/rspec'
require 'open-uri'
require 'json'
require 'dynamic-dynamodb-manager'

ENV['RACK_ENV'] ||= 'test'

# disable connection to external services
WebMock.disable_net_connect!(allow_localhost: true)

# Setup bundler with those options
Bundler.setup(:default, :test)

# Include Rack::Test::Methods
include Rack::Test::Methods

# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    tables = File.open(File.dirname(__FILE__) + '/support/fixtures/tables.json', 'rb').read
    stub_request(:get, "http://rest.mollom.com/v1/system/tables").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => tables, :headers => {})
  end
end