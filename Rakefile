#!/usr/bin/env rake
require 'bundler'
require 'pp'
require 'dynamic_dynamodb_manager'

task default: [:test]

task :test do
  `bundle exec rspec spec/`
end

task :local_dynamo do
  # fake_dynamo is no longer maintained (https://github.com/ananthakumaran/fake_dynamo)
  # Use DynamoDB Local instaed (http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html)
  # sh("fake_dynamo --port 4567 --db /tmp/#{ENV['USER']}/db.fdb")
  `/usr/bin/java -Djava.library.path=$HOME/DynamoDB/DynamoDBLocal_lib -jar $HOME/DynamoDB/DynamoDBLocal.jar -port 4567 -inMemory`
end

task :local_redis do
  `/usr/local/bin/redis-server`
end

# Setup the necessary gems, specified in the gemspec.
begin
  Bundler.setup(:default, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end
