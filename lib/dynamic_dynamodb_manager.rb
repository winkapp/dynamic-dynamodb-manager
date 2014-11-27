require 'open-uri'
require 'aws-sdk'
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

class DynamicDynamoDBManager

  attr_reader :dynamo_client
  attr_accessor :api_tables
  attr_accessor :dynamodb_required_tables
  attr_accessor :dynamodb_tables

  def initialize(aws_config = nil)

    # Setup default configs using dotenv libraries
    ENV['DYNAMODB_ENDPOINT'] ||= "localhost"
    ENV['DYNAMODB_PORT'] ||= '4567'
    ENV['AWS_ACCESS_KEY'] ||= '00000'
    ENV['AWS_SECRET_ACCESS_KEY'] ||= '00000'
    ENV['DYNAMODB_API_VERSION'] ||= '2012-08-10'
    ENV['DYNAMODB_USE_SSL'] ||= '0'
    ENV['API_TABLE_RESOURCE'] ||= 'http://testing.com/v1/system/tables'
    ENV['DYNAMODB_SLEEP_INTERVAL'] ||= "5"

    default_configs = { :dynamo_db_endpoint => ENV['DYNAMODB_ENDPOINT'],
                   :dynamo_db_port     => ENV['DYNAMODB_PORT'].to_i,
                   :access_key_id      => ENV['AWS_ACCESS_KEY'].to_s,
                   :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'].to_s,
                   :api_version        => ENV['DYNAMODB_API_VERSION'],
                   :use_ssl            => ENV['DYNAMODB_USE_SSL'] == 1 }

    if aws_config.nil? || aws_config.empty?
      options = default_configs
    else
      options = default_configs.merge(aws_config)
    end

    # Add some static caching. We know we don't need to ask AWS too much more after initialization.
    AWS.config(options)
    @dynamo_client = AWS::DynamoDB::Client.new(:api_version => ENV['DYNAMODB_API_VERSION'])
    @dynamodb_required_tables = get_all_required_tables
    @dynamodb_tables = get_all_tables
  end

  def get_all_tables(refresh = false, include_other = false)
    if refresh.equal?(false) and !@dynamodb_tables.nil?
      tables = @dynamodb_tables
    else
      tables = []
      tables_data = {:table_names => {}, :last_evaluated_table_name => ""}

      loop do
        data_more = {:limit => 100}
        if tables_data[:last_evaluated_table_name] != ""
          data_more[:exclusive_start_table_name] = tables_data[:last_evaluated_table_name]
        end
        tables_data = dynamo_client.list_tables(data_more)
        tables = tables + tables_data[:table_names]
        if tables_data[:last_evaluated_table_name].nil?
          break
        end
      end

      tables.each do | table |
        # If it is part of a different environment, do not list it
        if !(table.include? ENV['RACK_ENV']) and include_other.equal?(false)
          tables.delete(table)
          next
        end

        begin
          table_info = dynamo_client.describe_table({:table_name => table})
          # Remove the table from the current list of tables if it is in a deleting state
          if table_info[:table_status] == 'DELETING'
            tables.delete(table)
          end
        rescue ResourceNotFoundException
          # rescuing the ResourceNotFoundException means it might have
          # been in a delete state and listed but not present anymore
          tables.delete(table)
        end

      end
      @dynamodb_tables = tables
    end
    tables
  end

  def get_all_required_tables(refresh = false)
    if refresh.equal?(false) and !@dynamodb_required_tables.nil?
      tables = @dynamodb_required_tables
    else
      api_tables = get_table_scheme
      tables = Array.new

      # @todo Make this more error-proof
      api_tables.each do | table|
        rotation_scheme = table['RotationScheme']
        purge_rotation = table['PurgeRotation'].to_i
        table_name = table['TableName']
        environment = ENV['RACK_ENV']

        # If purge rotation equals infinite, we still will create at least 4 tables.
        # We do this to make sure it will create a new table and have at least a couple of
        # tables so the app can write historical data to it.
        if purge_rotation.equal?(-1)
          purge_rotation = 4
        end

        case rotation_scheme
          when "none"
            # syntax
            # stack.tablename
            temp_table = Marshal.load(Marshal.dump(table))
            temp_table['TableName'] = "#{environment}.#{table_name}"
            tables << temp_table
          when "daily"
            # syntax
            # stack.tablename.20041011
            i = 0
            start_date = Date.today + 1
            days = purge_rotation + 1
            while i < days  do
              table_prefix = start_date-i
              i=i+1
              # Create a deep copy by taking the variables and copy them into the new object
              # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
              temp_table = Marshal.load(Marshal.dump(table))
              temp_table['TableName'] = "#{environment}.#{table_name}."+table_prefix.strftime('%Y%m%d')
              tables << temp_table
            end
          when "weekly"
            # syntax
            # stack.tablename.20041011
            i = 0
            days = purge_rotation * 7 + 1

            start_date = Date.today
            start_date += 1 + ((0-start_date.wday) % 7)

            while i < days  do
              table_prefix = start_date-i
              i=i+7
              # Create a deep copy by taking the variables and copy them into the new object
              # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
              temp_table = Marshal.load(Marshal.dump(table))
              temp_table['TableName'] = "#{environment}.#{table_name}."+table_prefix.strftime('%Y%m%d')
              tables << temp_table
            end
          when "monthly"
            i = 0
            # Add one more month so we have a buffer when we purge
            months = purge_rotation+1
            # Create a dateTime object with x+1 month in the past so we can
            # start counting up from there
            dt = Time.new().to_datetime. << months
            while i < months  do
              # Setting our real date with 2 months in the future as offset
              table_prefix = dt >> i+2
              i=i+1
              # Create a deep copy by taking the variables and copy them into the new object
              # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
              temp_table = Marshal.load(Marshal.dump(table))
              # Forced to 01 as we always want the first of the month
              temp_table['TableName'] = "#{environment}.#{table_name}."+table_prefix.strftime('%Y%m%d')
              tables << temp_table
            end
          else
            raise "RotationScheme #{rotation_scheme} is not supported"
        end
      end
    end
    @dynamodb_required_tables = tables
    tables
  end

  def create_dynamodb_tables()
    tables = @dynamodb_required_tables
    tables.each do | table |

      attribute_definitions = Array.new
      table['Properties']['AttributeDefinitions'].each do |ad|
        attribute = { attribute_name: ad['AttributeName'], attribute_type: ad['AttributeType'] }
        attribute_definitions << attribute
      end
      key_schema = Array.new
      table['Properties']['KeySchema'].each do |ad|
        attribute = { attribute_name: ad['AttributeName'], key_type: ad['KeyType'] }
        key_schema << attribute
      end

      read_capacity_units = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits'].to_i
      write_capacity_units = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits'].to_i
      table_name = table['TableName']

      new_table_params = { attribute_definitions: attribute_definitions,
                           key_schema: key_schema,
                           provisioned_throughput: { read_capacity_units: read_capacity_units, write_capacity_units: write_capacity_units },
                           table_name: table_name }

      # Do not create tables that already exist
      if @dynamodb_tables.include?(table_name)
        puts "#{table_name} already exists. Skipping..."
      else
        puts "Creating #{table_name}. System will sleep for #{ENV['DYNAMODB_SLEEP_INTERVAL']} seconds for AWS limit purposes."
        dynamo_client.create_table(new_table_params)
        # Sleep for 5 seconds so that we give AWS some time to create the table
        sleep ENV['DYNAMODB_SLEEP_INTERVAL'].to_i
      end
    end
  end

  def cleanup_tables()
    all_tables = @dynamodb_required_tables

    # Get all our expected tables
    expected_tables = Array.new
    all_tables.each do | table |
      expected_tables << table['TableName']
    end

    # Get all existing tables
    existing_tables = @dynamodb_tables

    # Make the diff between those.
    remaining_tables = existing_tables - expected_tables

    # Remove all tables that are remaining
    remaining_tables.each do | table_name |
      # Check if it is part of this environment
      if table_name.include? ENV['RACK_ENV']
        # Check if the table name is known
        if @dynamodb_tables.include?(table_name)
          # Check if it has a rotation scheme.
          if table_name.include? '.'
            clean_tablename = table_name.split(/\./)[1]
            table_scheme = get_table_scheme(clean_tablename)
            if table_scheme['PurgeRotation'].to_i.equal?(-1)
              puts "Not deleting #{table_name}. Rotation was set to infinite."
              # go to the next table
              next
            end
          end
          # Not known to us and also no infinite rotation
          puts "Deleting #{table_name}. System will sleep for #{ENV['DYNAMODB_SLEEP_INTERVAL']} seconds for AWS limit purposes."
          dynamo_client.delete_table({table_name: table_name })
          # Sleep for 5 seconds so that we give AWS some time to create the table
          sleep ENV['DYNAMODB_SLEEP_INTERVAL'].to_i
        end
      end
    end
    # Refresh all tables
    get_all_tables(true)
  end

  def write_dynamic_dynamodb_config(path = '/tmp/dynamic-dynamodb.conf')
    cur_dir  = File.dirname(__FILE__)
    template = File.read(cur_dir+"/../templates/dynamic-dynamodb.erb")
    renderer = ERB.new(template)
    File.open(path, 'w+') { |file| file.write(renderer.result(binding)) }
  end

  def get_table_scheme(table_name = nil)
    begin
      tables_json = open(ENV['API_TABLE_RESOURCE']) { |f| f.read }
      api_tables = JSON.load(tables_json)
    rescue
      raise "JSON file #{ENV['API_TABLE_RESOURCE']} could not properly be read. Please make sure your source is accurate."
    end

    unless table_name.nil?
      api_tables.each do | table_definition|
        if table_definition['TableName'] == table_name
          return table_definition
        end
      end
    end
    # If not specified, return all tables
    api_tables
  end


end