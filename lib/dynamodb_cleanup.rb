require 'open-uri'
require 'aws-sdk-v1'
require 'json'
require 'erb'
require 'dotenv'
require 'pp'
require 'open-uri'
require 'date'

ENV['RACK_ENV'] ||= 'development'
puts "Loading with environment #{ENV['RACK_ENV']}"
Dotenv.load("../#{ENV['RACK_ENV']}.env")

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

class DynamoDbCleanup

  def initialize(aws_config = nil)

    ENV['AWS_ACCESS_KEY'] ||= '00000'
    ENV['AWS_SECRET_ACCESS_KEY'] ||= '00000'

    default_configs = {
      :access_key_id      => ENV['AWS_ACCESS_KEY'].to_s,
      :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'].to_s,
    }

    if aws_config.nil? || aws_config.empty?
      options = default_configs
    else
      options = default_configs.merge(aws_config)
    end

    # Add some static caching. We know we don't need to ask AWS too much more after initialization.
    AWS.config(options)
    @cf = AWS::CloudFormation.new(region: 'us-east-1')
  end

  def get_all_environments()
    environments = Array.new
    @cf.stacks.each do | stack |
      environment = stack.parameters['EnvironmentName']
      unless environment.nil?
        environments.push(environment) unless environments.include?(environment)
      end
      environments.push("production") unless environments.include?("production")
    end
    environments
  end

  def delete_unknown_tables()
    @manager = DynamicDynamoDBManager.new
    # Get all existing tables, include all
    all_tables = @manager.get_all_tables(true, true)
    environments = get_all_environments
    all_tables.each do | table_name |
      # Check if it is part of any known environment
      environments_regex = /#{environments.join("|")}/ # assuming there are no special chars

      if environments_regex === table_name
        pp "#{table_name} is part of the party"
      else
        # Not known to us and also no infinite rotation
        puts "Deleting #{table_name} because it is not known to any environment. System will sleep for #{ENV['DYNAMODB_SLEEP_INTERVAL']} seconds for AWS limit purposes."
        @manager.delete_table(table_name)
        # Sleep for 5 seconds so that we give AWS some time to create the table
        sleep ENV['DYNAMODB_SLEEP_INTERVAL'].to_i
      end
    end
  end
end
