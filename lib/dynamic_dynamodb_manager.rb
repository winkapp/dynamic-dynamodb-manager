require 'open-uri'
require 'aws-sdk'
require 'json'
require 'erb'
require 'dotenv'
require 'pp'
require 'open-uri'
require 'date'
require 'redis'

ENV['RACK_ENV'] ||= 'test'
if File.file?("../#{ENV['RACK_ENV']}.env")
  puts "Loading with environment #{ENV['RACK_ENV']}"
  Dotenv.load("../#{ENV['RACK_ENV']}.env")
end

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
  attr_accessor :verbose

  def initialize(aws_config: nil, verbose: true)
    ENV['AWS_REGION'] ||= 'us-east-1'
    ENV['AWS_ACCESS_KEY'] ||= '00000'
    ENV['AWS_SECRET_ACCESS_KEY'] ||= '00000'
    default_configs = {
      access_key_id: ENV['AWS_ACCESS_KEY'].to_s,
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'].to_s
    }

    if ENV['RACK_ENV'].eql? 'test'
      # Setup default configs using dotenv libraries
      ENV['DYNAMODB_ENDPOINT'] ||= 'localhost'
      ENV['DYNAMODB_PORT'] ||= '4567'
      ENV['DYNAMODB_USE_SSL'] ||= '0'
      ENV['API_TABLE_RESOURCE'] ||= 'http://testing.com/v1/system/tables'
      ENV['DYNAMODB_SLEEP_INTERVAL'] ||= '10'

      protocol = 'http'
      protocol += 's' if ENV['DYNAMODB_USE_SSL'] == '1'
      endpoint = "#{protocol}://#{ENV['DYNAMODB_ENDPOINT']}:#{ENV['DYNAMODB_PORT']}"
      default_configs.update(endpoint: endpoint)
    else
      ENV['DYNAMODB_SLEEP_INTERVAL'] ||= '5'
    end

    options = if aws_config.nil? || aws_config.empty?
                default_configs
              else
                default_configs.merge(aws_config)
              end

    # Add some static caching. We know we don't need to ask AWS too much more after initialization.
    Aws.config = options
    @dynamo_client = Aws::DynamoDB::Client.new
    @dynamodb_required_tables = get_all_required_tables
    @dynamodb_tables = get_all_tables

    @verbose = verbose
  end

  def get_all_tables(refresh = false, include_other = false)
    if !refresh && !@dynamodb_tables.nil?
      tables = @dynamodb_tables
    else
      tables = []
      tables_data = { table_names: {}, last_evaluated_table_name: '' }

      loop do
        data_more = { limit: 100 }
        if tables_data[:last_evaluated_table_name] != ''
          data_more[:exclusive_start_table_name] = tables_data[:last_evaluated_table_name]
        end
        tables_data = dynamo_client.list_tables(data_more)
        tables += tables_data[:table_names]
        break if tables_data[:last_evaluated_table_name].nil?
      end

      tables.each do |table|
        # If it is part of a different environment, do not list it
        if !table.start_with?("#{ENV['RACK_ENV']}.") && !include_other
          tables.delete(table)
          next
        end

        begin
          table_info = dynamo_client.describe_table(table_name: table)
          # Remove the table from the current list of tables if it is in a deleting state
          tables.delete(table) if table_info.table[:table_status] == 'DELETING'
        rescue Aws::DynamoDB::Errors::ResourceNotFoundException
          # ResourceNotFoundException - it might have been in a delete state and listed
          # but not present anymore
          tables.delete(table)
        rescue Aws::DynamoDB::Errors::AccessDeniedException
          # AccessDeniedException - it is a table that we shouldnt be touching
          tables.delete(table)
        end
      end
      @dynamodb_tables = tables
    end
    tables
  end

  def delete_table(table_name)
    table = get_table_scheme(table_name.split(/\./)[1])
    if !table.nil? && table.include?('StreamLambda')
      # noinspection RubyResolve,RubyArgCount
      lambda_client = Aws::Lambda::Client.new

      table_info = dynamo_client.describe_table(table_name: table_name)
      stream_arn = table_info.table[:latest_stream_arn]
      func_name = table['StreamLambda']['FunctionName']

      if @verbose
        puts "Deleting event source mappings of stream #{stream_arn} to lambda: #{func_name}"
      end
      esms = lambda_client.list_event_source_mappings(event_source_arn: stream_arn,
                                                      function_name: func_name)
      esms.event_source_mappings.each do |esm|
        esm_uuid = esm.uuid
        lambda_client.delete_event_source_mapping(uuid: esm_uuid)
      end
    end

    puts "Deleting table: #{table_name}" if @verbose
    dynamo_client.delete_table(table_name: table_name)
  end

  def get_all_required_tables(refresh = false)
    if refresh.equal?(false) && !@dynamodb_required_tables.nil?
      tables = @dynamodb_required_tables
    else
      api_tables = get_table_scheme
      tables = []

      environment = ENV['RACK_ENV']

      # @todo Make this more error-proof
      api_tables.each do |table|
        rotation_scheme = table['RotationScheme']
        purge_rotation = table['PurgeRotation'].to_i
        table_name = table['TableName']

        # If purge rotation equals infinite, we still will create at least 4 tables.
        # We do this to make sure it will create a new table and have at least a couple of
        # tables so the app can write historical data to it.
        purge_rotation = 4 if purge_rotation.equal?(-1)

        case rotation_scheme
        when 'daily'
          # syntax
          # stack.tablename.20041011
          i = 0
          start_date = Date.today + 1
          days = purge_rotation + 1
          while i < days
            table_prefix = start_date - i
            i += 1
            # Create a deep copy by taking the variables and copy them into the new object
            # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
            temp_table = Marshal.load(Marshal.dump(table))
            temp_table['TableName'] = "#{environment}.#{table_name}.#{table_prefix.strftime('%Y%m%d')}"

            # if Throughput limitations are given, the first two iterations get TableProvisionedThroughput.
            # the latter get the OutdatedTableProvisionedThroughput
            if i == 2
              temp_table['PRIMARY_DYNAMODB_TABLE'] = true
            elsif i > 2
              temp_table['SECONDARY_DYNAMODB_TABLE'] = true if i == 3
              if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
              end
              if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                temp_table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
                  if gsi.include?('OutdatedTableProvisionedThroughput')
                    gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                  end
                end
              end
            end
            tables << temp_table
          end
        when 'weekly'
          # syntax
          # stack.tablename.20041011
          day_count = 0
          days = purge_rotation * 7 + 1

          start_date = Date.today
          start_date += 1 + ((0 - start_date.wday) % 7)

          while day_count < days
            table_prefix = start_date - day_count
            day_count += 7
            # Create a deep copy by taking the variables and copy them into the new object
            # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
            temp_table = Marshal.load(Marshal.dump(table))
            temp_table['TableName'] = "#{environment}.#{table_name}.#{table_prefix.strftime('%Y%m%d')}"

            # if Throughput limitations are given, the first week gets the ProvisionedThroughput and the day before
            # the next week is active, it will also receive the ProvisionedThroughput.
            # everything else gets the OutdatedTableProvisionedThroughput
            tomorrow = Date.today + 1
            if day_count.eql? 7
              # This is next week
              unless tomorrow.strftime('%Y%m%d').eql? table_prefix.strftime('%Y%m%d')
                if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                  temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                end
                if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                  temp_table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
                    if gsi.include?('OutdatedTableProvisionedThroughput')
                      gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                    end
                  end
                end
              end
            elsif day_count.eql? 14
              # This is current week
              temp_table['PRIMARY_DYNAMODB_TABLE'] = true
            else
              # This is everything prior to current week
              temp_table['SECONDARY_DYNAMODB_TABLE'] = true if day_count.eql? 21
              unless tomorrow.strftime('%Y%m%d').eql? table_prefix.strftime('%Y%m%d')
                if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                  temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                  end
                if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                  temp_table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
                    if gsi.include?('OutdatedTableProvisionedThroughput')
                      gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                        end
                  end
                end
              end
            end
            tables << temp_table
          end
        when 'monthly'
          i = 0
          # Add one more month so we have a buffer when we purge
          months = purge_rotation + 1
          # Create a dateTime object with x+1 month in the past so we can
          # start counting up from there
          dt = Time.new.to_datetime.<< months
          while i < months
            # Setting our real date with 2 months in the future as offset
            table_prefix = dt >> i + 2
            i += 1
            # Create a deep copy by taking the variables and copy them into the new object
            # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
            temp_table = Marshal.load(Marshal.dump(table))

            # Forced to 01 as we always want the first of the month
            temp_table['TableName'] = "#{environment}.#{table_name}.#{table_prefix.strftime('%Y%m01')}"

            tomorrow = Date.today + 1
            # since we always do one month in the future. Month with i equal to 1 is our current month.
            # Month 0 is the future month and only if the date of that new month is tomorrow, it will get
            # the updated ProvisionedThroughput
            if (months - i).eql? 1
              # Current Month
              # Set redis env var for PRIMARY_DYNAMODB_TABLE to temp_table['TableName']
              temp_table['PRIMARY_DYNAMODB_TABLE'] = true
            else
              if (months - i).eql? 2
                # Previous Month
                # Set redis env var for SECONDARY_DYNAMODB_TABLE to temp_table['TableName']
                temp_table['SECONDARY_DYNAMODB_TABLE'] = true
                end
              unless tomorrow.strftime('%Y%m%d').eql? table_prefix.strftime('%Y%m01')
                # if Throughput limitations are given, the first month gets the ProvisionedThroughput and the day before
                # the next month is active, it will also receive the ProvisionedThroughput.
                # everything else gets the OutdatedTableProvisionedThroughput
                if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                  temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                  end
                if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                  temp_table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
                    if gsi.include?('OutdatedTableProvisionedThroughput')
                      gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                        end
                  end
                end
              end
            end

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

  def create_tables
    # noinspection RubyResolve,RubyArgCount
    lambda_client = Aws::Lambda::Client.new

    tables = @dynamodb_required_tables
    tables.each do |table|
      table_name = table['TableName']
      # Do not create tables that already exist
      if @dynamodb_tables.include?(table_name)
        puts "#{table_name} already exists.  Not creating..." if @verbose
      else
        puts "Creating #{table_name}..." if @verbose
        attribute_definitions = []
        table['Properties']['AttributeDefinitions'].each do |ad|
          attribute = {
            attribute_name: ad['AttributeName'],
            attribute_type: ad['AttributeType']
          }
          attribute_definitions << attribute
        end
        key_schema = []
        table['Properties']['KeySchema'].each do |ad|
          attribute = {
            attribute_name: ad['AttributeName'],
            key_type: ad['KeyType']
          }
          key_schema << attribute
        end

        read_capacity_units = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits'].to_i
        write_capacity_units = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits'].to_i

        new_table_params = {
          attribute_definitions: attribute_definitions,
          key_schema: key_schema,
          provisioned_throughput: {
            read_capacity_units: read_capacity_units,
            write_capacity_units: write_capacity_units
          },
          table_name: table_name
        }

        if table['Properties'].include?('LocalSecondaryIndexes')
          local_si = []
          table['Properties']['LocalSecondaryIndexes'].each do |lsi|
            index_name = lsi['IndexName']
            lsi_key_schema = []
            lsi['KeySchema'].each do |ks|
              lsi_attribute = { attribute_name: ks['AttributeName'], key_type: ks['KeyType'] }
              lsi_key_schema << lsi_attribute
            end
            lsi_projection = {
              projection_type: lsi['Projection']['ProjectionType']
            }
            if lsi['Projection'].include?('NonKeyAttributes')
              lsi_projection[:non_key_attributes] = lsi['Projection']['NonKeyAttributes']
            end
            new_lsi = {
              index_name: index_name,
              key_schema: lsi_key_schema,
              projection: lsi_projection
            }
            local_si << new_lsi
          end
          new_table_params[:local_secondary_indexes] = local_si
        end

        if table['Properties'].include?('GlobalSecondaryIndexes')
          global_si = []
          table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
            index_name = gsi['IndexName']
            gsi_key_schema = []
            gsi['KeySchema'].each do |ks|
              gsi_attribute = { attribute_name: ks['AttributeName'], key_type: ks['KeyType'] }
              gsi_key_schema << gsi_attribute
            end
            gsi_projection = {
              projection_type: gsi['Projection']['ProjectionType']
            }
            if gsi['Projection'].include?('NonKeyAttributes')
              gsi_projection[:non_key_attributes] = gsi['Projection']['NonKeyAttributes']
            end
            gsi_read_capacity_units = gsi['ProvisionedThroughput']['ReadCapacityUnits'].to_i
            gsi_write_capacity_units = gsi['ProvisionedThroughput']['WriteCapacityUnits'].to_i
            new_gsi = {
              index_name: index_name,
              key_schema: gsi_key_schema,
              projection: gsi_projection,
              provisioned_throughput: {
                read_capacity_units: gsi_read_capacity_units,
                write_capacity_units: gsi_write_capacity_units
              }
            }
            global_si << new_gsi
          end
          new_table_params[:global_secondary_indexes] = global_si
        end

        if table['Properties'].include?('StreamSpecification')
          stream_specification = {
            stream_enabled: table['Properties']['StreamSpecification']['StreamEnabled'],
            stream_view_type: table['Properties']['StreamSpecification']['StreamViewType']
          }
          new_table_params[:stream_specification] = stream_specification
        end

        create_response = dynamo_client.create_table(new_table_params)

        # Sleep for N seconds so that we give AWS some time to create the table
        sleep_intv = ENV['DYNAMODB_SLEEP_INTERVAL']
        puts "Sleeping for #{sleep_intv} seconds for AWS limit purposes." if @verbose
        sleep sleep_intv.to_f

        # Create an event source mapping from the new DynamoDB stream to a lambda function
        if table.include?('StreamLambda')
          # @todo I dont think this is necessary since event source mappings are part of Lambda not DynamoDB so we shouldnt need to wait until the DB is ready
          #
          # status = dynamo_client.describe_table({:table_name => table_name}).table[:table_status]
          # while status != 'ACTIVE'
          #     if @verbose
          #         puts "Waiting for table to be ACTIVE: #{status}"
          #     end
          #     sleep 2
          #     status = dynamo_client.describe_table({:table_name => table_name}).table[:table_status]
          # end

          func_name = table['StreamLambda']['FunctionName']
          stream_arn = create_response.table_description.latest_stream_arn
          puts "Adding source mapping to lambda #{func_name} for stream #{stream_arn}..." if @verbose
          lambda_client.create_event_source_mapping(event_source_arn: stream_arn,
                                                    function_name: func_name,
                                                    enabled: table['StreamLambda']['Enabled'],
                                                    batch_size: table['StreamLambda']['BatchSize'],
                                                    starting_position: table['StreamLambda']['StartingPosition'])
        end
      end
    end
  end

  def update_tables
    all_tables = get_all_tables(true)
    tables = get_all_required_tables(true)
    tables.each do |table|
      table_name = table['TableName']
      # Do not update tables that do not exist
      if all_tables.include?(table_name)
        table_info = dynamo_client.describe_table(table_name: table_name)

        scheme_read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']
        scheme_write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
        actual_read_cap = table_info.table[:provisioned_throughput][:read_capacity_units]
        actual_write_cap = table_info.table[:provisioned_throughput][:write_capacity_units]

        if scheme_read_cap.eql?(actual_read_cap) && scheme_write_cap.eql?(actual_write_cap)
          puts "No update needed for #{table_name} table throughput capacity" if @verbose
        else
          puts "Updating #{table_name} table throughput capacity" if @verbose
          params = {
            table_name: table_name,
            provisioned_throughput: {
              read_capacity_units: scheme_read_cap,
              write_capacity_units: scheme_write_cap
            }
          }
          dynamo_client.update_table(params)
        end

        if table['Properties'].include?('GlobalSecondaryIndexes')
          new_gsis = []
          table['Properties']['GlobalSecondaryIndexes'].each do |scheme_gsi|
            index_name = scheme_gsi['IndexName']
            scheme_gsi_read_cap = scheme_gsi['ProvisionedThroughput']['ReadCapacityUnits'].to_i
            scheme_gsi_write_cap = scheme_gsi['ProvisionedThroughput']['WriteCapacityUnits'].to_i

            table_info.table[:global_secondary_indexes].each do |actual_gsi|
              next unless actual_gsi[:index_name].eql? index_name
              actual_gsi_read_cap = actual_gsi[:provisioned_throughput][:read_capacity_units]
              actual_gsi_write_cap = actual_gsi[:provisioned_throughput][:write_capacity_units]
              next if scheme_gsi_read_cap.eql?(actual_gsi_read_cap) && scheme_gsi_write_cap.eql?(actual_gsi_write_cap)
              new_gsi = {
                update: {
                  index_name: index_name,
                  provisioned_throughput: {
                    read_capacity_units: scheme_gsi_read_cap,
                    write_capacity_units: scheme_gsi_write_cap
                  }
                }
              }
              new_gsis << new_gsi
            end
          end
          if new_gsis.empty?
            puts "No update needed for #{table_name} GSI throughput capacity" if @verbose
          else
            puts "Updating #{table_name} GSI throughput capacity" if @verbose
            params = {
              table_name: table_name,
              global_secondary_index_updates: new_gsis
            }
            dynamo_client.update_table(params)
          end
        end
      else
        puts "Table '#{table_name}' does not exist." if @verbose
      end
    end
  end

  def update_redis
    env_override = 'env_override_hash'
    primary_field = 'PRIMARY_DYNAMODB_TABLE'
    secondary_field = 'SECONDARY_DYNAMODB_TABLE'
    redis_client = Redis.new(url: ENV['REDIS_URL'])
    tables = get_all_required_tables(true)
    tables.each do |table|
      table_name = table['TableName']
      clean_tablename = table_name.split(/\./)[1].gsub(/[^\w]/, '_').upcase
      if table[primary_field]
        primary_field_name = "DYNAMODB_PRIMARY_#{clean_tablename}"
        unless redis_client.hget(env_override, primary_field_name).eql?(table_name)
          puts "Setting #{primary_field_name} env var override to #{table_name}" if @verbose
          redis_client.hset(env_override, primary_field_name, table_name)
        end
      end
      next unless table[secondary_field]
      secondary_field_name = "DYNAMODB_SECONDARY_#{clean_tablename}"
      next if redis_client.hget(env_override, secondary_field_name).eql?(table_name)
      puts "Setting #{secondary_field_name} env var override to #{table_name}" if @verbose
      redis_client.hset(env_override, secondary_field_name, table_name)
    end
  end

  def cleanup_tables
    rack_env = ENV['RACK_ENV']
    sleep_intv = ENV['DYNAMODB_SLEEP_INTERVAL']

    all_tables = @dynamodb_required_tables

    # Get all our expected tables
    expected_tables = []
    all_tables.each do |table|
      expected_tables << table['TableName']
    end

    # Get all existing tables
    existing_tables = @dynamodb_tables

    # Make the diff between those.
    remaining_tables = existing_tables - expected_tables

    # Remove all tables that are remaining
    remaining_tables.each do |table_name|
      # Check if table name matches our naming convention (environ.name.YearMonthDay)
      # If this code is still in use past the year 2099 I will be amazed
      next if table_name.match(/^#{rack_env}\..+\.20\d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[01])$/).nil?

      # Check if it has a rotation scheme.
      clean_tablename = table_name.split(/\./)[1]
      table_scheme = get_table_scheme(clean_tablename)

      if table_scheme.nil?
        puts "Not deleting #{table_name}.  Not found in API_TABLE_RESOURCE json." if @verbose
        # go to the next table
        next
      elsif table_scheme['PurgeRotation'].to_i.equal?(-1)
        puts "Not deleting #{table_name}.  Rotation is set to infinite." if @verbose
        # go to the next table
        next
      end

      puts "Deleting #{table_name}..." if @verbose
      delete_table(table_name)

      # Sleep for N seconds so that we give AWS some time to create the table
      puts "Sleeping for #{sleep_intv} seconds for AWS limit purposes." if @verbose
      sleep sleep_intv.to_f
    end
    # Refresh all tables
    get_all_tables(true)
  end

  def write_dynamic_dynamodb_config(path = '/tmp/dynamic-dynamodb.conf')
    cur_dir = File.dirname(__FILE__)
    template = File.read("#{cur_dir}/../templates/dynamic-dynamodb.erb")
    renderer = ERB.new(template)
    File.open(path, 'w+') { |file| file.write(renderer.result(binding)) }
  end

  def get_table_scheme(table_name = nil)
    begin
      tables_json = open(ENV['API_TABLE_RESOURCE'], &:read)
      api_tables = JSON.load(tables_json)
    rescue
      raise "JSON file #{ENV['API_TABLE_RESOURCE']} could not properly be read. Please make sure your source is accurate."
    end

    if table_name.nil?
      # If not specified, return all tables
      api_tables
    else
      api_tables.each do |table_definition|
        return table_definition if table_definition['TableName'] == table_name
      end
      nil
    end
  end
end
