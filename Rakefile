#!/usr/bin/env rake
require 'bundler'
require 'pp'
require 'dynamic_dynamodb_manager/dynamic_dynamodb_manager'

task :default => [:test]

task :test do
  sh("bundle exec rspec spec/")
end

desc "Writes the dynamic db config"
task :write_config do
  ENV['DYNAMIC_CONFIG_FILE'] ||= ' /etc/dynamic-dynamodb/dynamic-dynamodb.conf'
  @manager = DynamicDynamoDBManager.new
  @manager.write_dynamic_dynamodb_config(ENV['DYNAMIC_CONFIG_FILE'])
  puts "wrote the Dynamic DynamoDB config file to #{ENV['DYNAMIC_CONFIG_FILE']}"
end

task :fake_dynamo do
  sh("fake_dynamo --port 4567 --db /tmp/"+ENV['USER']+"/db.fdb")
end

# Setup the necessary gems, specified in the gemspec.
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end