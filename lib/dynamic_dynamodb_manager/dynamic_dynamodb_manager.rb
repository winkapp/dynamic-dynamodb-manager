require 'open-uri'
require 'aws-sdk'
require 'json'
require 'dynamic_dynamodb_manager/dynamic_dynamodb_manager'
require 'erb'
require 'dotenv'
require 'pp'
require 'open-uri'

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

class DynamicDynamoDBManager

  attr_reader :dynamo_client
  attr_accessor :api_tables

  def initialize(aws_config = nil)

    # Setup default configs using dotenv libraries
    ENV['DYNAMODB_ENDPOINT'] ||= "localhost"
    ENV['DYNAMODB_PORT'] ||= 4567
    ENV['AWS_ACCESS_KEY'] ||= "00000"
    ENV['AWS_SECRET_ACCESS_KEY'] ||= "00000"
    ENV['DYNAMODB_API_VERSION'] ||= "2012-08-10"
    ENV['DYNAMODB_USE_SSL'] ||= false
    ENV['API_TABLE_RESOURCE'] ||= 'http://testing.com/v1/system/tables'

    default_configs = { :dynamo_db_endpoint => ENV['DYNAMODB_ENDPOINT'],
                   :dynamo_db_port     => ENV['DYNAMODB_PORT'].to_i,
                   :access_key_id      => ENV['AWS_ACCESS_KEY'],
                   :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
                   :api_version        => ENV['DYNAMODB_API_VERSION'],
                   :use_ssl            => ENV['DYNAMODB_USE_SSL'] == 1 }

    if aws_config.nil? || aws_config.empty?
      options = default_configs
    else
      options = default_configs.merge(aws_config)
    end

    AWS.config(options)
    @dynamo_client = AWS::DynamoDB::Client.new(:api_version => ENV['DYNAMODB_API_VERSION'])
    tables = open(ENV['API_TABLE_RESOURCE']) { |f| f.read }
    @api_tables = JSON.load(tables)
  end

  def collections()
    dynamo_client.list_tables[:table_names]
  end

  def get_api_tables()
   api_tables
  end

  def create_dynamodb_tables()
    api_tables.each{ | table |

      attribute_definitions = Array.new
      table['Properties']['AttributeDefinitions'].each { |ad|
        attribute = { attribute_name: ad['AttributeName'], attribute_type: ad['AttributeType'] }
        attribute_definitions << attribute
      }
      key_schema = Array.new
      table['Properties']['KeySchema'].each { |ad|
        attribute = { attribute_name: ad['AttributeName'], key_type: ad['KeyType'] }
        key_schema << attribute
      }

      read_capacity_units = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits'].to_i
      write_capacity_units = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits'].to_i
      table_name = table['TableName']

      new_table_params = { attribute_definitions: attribute_definitions,
                           key_schema: key_schema,
                           provisioned_throughput: { read_capacity_units: read_capacity_units, write_capacity_units: write_capacity_units },
                           table_name: table_name }

      dynamo_client.create_table(new_table_params)
    }
  end

  def write_dynamic_dynamodb_config(path = '/tmp/dynamic-dynamodb.conf')
    template = File.read("templates/dynamic-dynamodb.erb")
    renderer = ERB.new(template)
    File.open(path, 'w+') { |file| file.write(renderer.result(binding)) }
  end

end