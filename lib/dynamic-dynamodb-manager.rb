require 'aws-sdk'
require 'json'
require 'dynamic_dynamodb_manager/dynamic_dynamodb_manager'
require 'erb'
require 'dotenv'
require 'pp'

ENV['RACK_ENV'] ||= 'development'
puts "Loading with environment #{ENV['RACK_ENV']}"
Dotenv.load("#{ENV['RACK_ENV']}.env")

if ENV['BUGSNAG_APIKEY']
  require 'bugsnag'
  Bugsnag.configure do |config|
    config.api_key = ENV['BUGSNAG_APIKEY']
    config.use_ssl = true
    config.notify_release_stages = ['production']
    config.project_root = '/search'
    config.app_version = ENV['VERSION']
    config.release_stage = ENV['RACK_ENV']
  end
end