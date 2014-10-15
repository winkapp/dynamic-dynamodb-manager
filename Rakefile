#!/usr/bin/env rake
require 'bundler'
require 'pp'
require 'dynamic_dynamodb_manager'

task :default => [:test]

task :test do
  sh("bundle exec rspec spec/")
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