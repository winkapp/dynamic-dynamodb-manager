require 'open-uri'
require 'aws-sdk'
require 'json'
require 'erb'
require 'dotenv'
require 'pp'
require 'open-uri'
require 'date'

ENV['RACK_ENV'] ||= 'test'
unless ENV['RACK_ENV'].equal?('production')
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

    def initialize(aws_config = nil)

        ENV['AWS_ACCESS_KEY'] ||= '00000'
        ENV['AWS_SECRET_ACCESS_KEY'] ||= '00000'
        default_configs = {
            :access_key_id => ENV['AWS_ACCESS_KEY'].to_s,
            :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'].to_s
        }
        unless ENV['RACK_ENV'].equal?('production')
            # Setup default configs using dotenv libraries
            ENV['DYNAMODB_ENDPOINT'] ||= 'localhost'
            ENV['DYNAMODB_PORT'] ||= '4567'
            ENV['DYNAMODB_USE_SSL'] ||= '0'
            ENV['API_TABLE_RESOURCE'] ||= 'http://testing.com/v1/system/tables'
            ENV['DYNAMODB_SLEEP_INTERVAL'] ||= '5'

            protocol = 'http'
            if ENV['DYNAMODB_USE_SSL'] == '1'
                protocol += 's'
            end
            endpoint = "#{protocol}://#{ENV['DYNAMODB_ENDPOINT']}:#{ENV['DYNAMODB_PORT']}"
            default_configs.update({:endpoint => endpoint})
        end

        if aws_config.nil? || aws_config.empty?
            options = default_configs
        else
            options = default_configs.merge(aws_config)
        end

        # Add some static caching. We know we don't need to ask AWS too much more after initialization.
        Aws.config = options
        @dynamo_client = Aws::DynamoDB::Client.new
        @dynamodb_required_tables = get_all_required_tables
        @dynamodb_tables = get_all_tables
    end

    def get_all_tables(refresh = false, include_other = false)
        if refresh.equal?(false) and !@dynamodb_tables.nil?
            tables = @dynamodb_tables
        else
            tables = []
            tables_data = {:table_names => {}, :last_evaluated_table_name => ''}

            loop do
                data_more = {:limit => 100}
                if tables_data[:last_evaluated_table_name] != ''
                    data_more[:exclusive_start_table_name] = tables_data[:last_evaluated_table_name]
                end
                tables_data = dynamo_client.list_tables(data_more)
                tables = tables + tables_data[:table_names]
                if tables_data[:last_evaluated_table_name].nil?
                    break
                end
            end

            tables.each do |table|
                # If it is part of a different environment, do not list it
                if !(table.include? ENV['RACK_ENV']) and include_other.equal?(false)
                    tables.delete(table)
                    next
                end

                begin
                    table_info = dynamo_client.describe_table({:table_name => table})
                    # Remove the table from the current list of tables if it is in a deleting state
                    if table_info.table[:table_status] == 'DELETING'
                        tables.delete(table)
                    end
                rescue Aws::DynamoDB::Errors::ResourceNotFoundException
                    # rescuing the ResourceNotFoundException means it might have
                    # been in a delete state and listed but not present anymore
                    tables.delete(table)
                end

            end
            @dynamodb_tables = tables
        end
        tables
    end

    def delete_table(table_name)
        puts "Would delete table: #{table_name}"
        # dynamo_client.delete_table({table_name: table_name})
    end

    def get_all_required_tables(refresh = false)
        if refresh.equal?(false) and !@dynamodb_required_tables.nil?
            tables = @dynamodb_required_tables
        else
            api_tables = get_table_scheme
            tables = Array.new

            environment = ENV['RACK_ENV']

            # @todo Make this more error-proof
            api_tables.each do |table|
                rotation_scheme = table['RotationScheme']
                purge_rotation = table['PurgeRotation'].to_i
                table_name = table['TableName']


                # If purge rotation equals infinite, we still will create at least 4 tables.
                # We do this to make sure it will create a new table and have at least a couple of
                # tables so the app can write historical data to it.
                if purge_rotation.equal?(-1)
                    purge_rotation = 4
                end

                case rotation_scheme
                    when 'none'
                        # syntax
                        # stack.tablename
                        temp_table = Marshal.load(Marshal.dump(table))
                        temp_table['TableName'] = "#{environment}.#{table_name}"
                        tables << temp_table
                    when 'daily'
                        # syntax
                        # stack.tablename.20041011
                        i = 0
                        start_date = Date.today + 1
                        days = purge_rotation + 1
                        while i < days do
                            table_prefix = start_date - i
                            i += 1
                            # Create a deep copy by taking the variables and copy them into the new object
                            # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
                            temp_table = Marshal.load(Marshal.dump(table))
                            temp_table['TableName'] = "#{environment}.#{table_name}.#{table_prefix.strftime('%Y%m%d')}"

                            # if Throughput limitations are given, the first two iterations get TableProvisionedThroughput.
                            # the latter get the OutdatedTableProvisionedThroughput
                            if i > 2
                                if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                                    temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                                end
                                if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                                    temp_table['Properties']['GlobalSecondaryIndexes'].each { |gsi|
                                        if gsi.include?('OutdatedTableProvisionedThroughput')
                                            gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                                        end
                                    }
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

                        while day_count < days do
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
                                        temp_table['Properties']['GlobalSecondaryIndexes'].each { |gsi|
                                            if gsi.include?('OutdatedTableProvisionedThroughput')
                                                gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                                            end
                                        }
                                    end
                                end
                            end
                            # everything except current week
                            unless day_count.eql? 14
                                unless tomorrow.strftime('%Y%m%d').eql? table_prefix.strftime('%Y%m%d')
                                    if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                                        temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                                    end
                                    if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                                        temp_table['Properties']['GlobalSecondaryIndexes'].each { |gsi|
                                            if gsi.include?('OutdatedTableProvisionedThroughput')
                                                gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                                            end
                                        }
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
                        while i < months do
                            # Setting our real date with 2 months in the future as offset
                            table_prefix = dt >> i + 2
                            i += 1
                            # Create a deep copy by taking the variables and copy them into the new object
                            # @see http://ruby.about.com/od/advancedruby/a/deepcopy.htm
                            temp_table = Marshal.load(Marshal.dump(table))

                            # Forced to 01 as we always want the first of the month
                            temp_table['TableName'] = "#{environment}.#{table_name}.#{table_prefix.strftime('%Y%m01')}"

                            # since we always do one month in the future. Month with i equal to 1 is our current month.
                            # Month 0 is the future month and only if the date of that new month is tomorrow, it will get
                            # the updated ProvisionedThroughput
                            unless (months - i).eql? 1
                                # if Throughput limitations are given, the first month gets the ProvisionedThroughput and the day before
                                # the next month is active, it will also receive the ProvisionedThroughput.
                                # everything else gets the OutdatedTableProvisionedThroughput
                                tomorrow = Date.today + 1

                                # TODO: change 19 to 01
                                unless tomorrow.strftime('%Y%m%d').eql? table_prefix.strftime('%Y%m01')
                                    if temp_table['Properties'].include?('OutdatedTableProvisionedThroughput')
                                        temp_table['Properties']['ProvisionedThroughput'] = temp_table['Properties']['OutdatedTableProvisionedThroughput']
                                    end
                                    if temp_table['Properties'].include?('GlobalSecondaryIndexes')
                                        temp_table['Properties']['GlobalSecondaryIndexes'].each { |gsi|
                                            if gsi.include?('OutdatedTableProvisionedThroughput')
                                                gsi['ProvisionedThroughput'] = gsi['OutdatedTableProvisionedThroughput']
                                            end
                                        }
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
        tables = @dynamodb_required_tables
        tables.each do |table|
            table_name = table['TableName']
            # Do not create tables that already exist
            if @dynamodb_tables.include?(table_name)
                puts "#{table_name} already exists. Skipping..."
            else
                attribute_definitions = Array.new
                table['Properties']['AttributeDefinitions'].each do |ad|
                    attribute = {
                        attribute_name: ad['AttributeName'],
                        attribute_type: ad['AttributeType']
                    }
                    attribute_definitions << attribute
                end
                key_schema = Array.new
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
                    local_si = Array.new
                    table['Properties']['LocalSecondaryIndexes'].each do |lsi|
                        index_name = lsi['IndexName']
                        lsi_key_schema = Array.new
                        lsi['KeySchema'].each do |ks|
                            lsi_attribute = {attribute_name: ks['AttributeName'], key_type: ks['KeyType']}
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
                    global_si = Array.new
                    table['Properties']['GlobalSecondaryIndexes'].each do |gsi|
                        index_name = gsi['IndexName']
                        gsi_key_schema = Array.new
                        gsi['KeySchema'].each do |ks|
                            gsi_attribute = {attribute_name: ks['AttributeName'], key_type: ks['KeyType']}
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

                puts "Creating #{table_name}..."
                dynamo_client.create_table(new_table_params)
                # Sleep for N seconds so that we give AWS some time to create the table
                sleep_intv = ENV['DYNAMODB_SLEEP_INTERVAL']
                puts "Sleeping for #{sleep_intv} seconds for AWS limit purposes."
                sleep sleep_intv.to_f
            end
        end
    end

    def update_tables
        tables = get_all_required_tables(true)
        tables.each do |table|
            table_name = table['TableName']
            # Do not create tables that already exist
            if @dynamodb_tables.include?(table_name)
                table_info = dynamo_client.describe_table({:table_name => table_name})

                # table_scheme = get_table_scheme(table_name)
                scheme_read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']
                scheme_write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                actual_read_cap = table_info.table[:provisioned_throughput][:read_capacity_units]
                actual_write_cap = table_info.table[:provisioned_throughput][:write_capacity_units]

                if scheme_read_cap.eql?(actual_read_cap) and scheme_write_cap.eql?(actual_write_cap)
                    puts "No update needed for #{table_name} table throughput capacity"
                else
                    puts "Updating #{table_name} table throughput capacity"
                    params = {
                        :table_name => table_name,
                        :provisioned_throughput => {
                            :read_capacity_units => scheme_read_cap,
                            :write_capacity_units => scheme_write_cap
                        }
                    }
                    dynamo_client.update_table(params)
                end

                if table['Properties'].include?('GlobalSecondaryIndexes')
                    new_gsis = Array.new
                    table['Properties']['GlobalSecondaryIndexes'].each do |scheme_gsi|
                        index_name = scheme_gsi['IndexName']
                        scheme_gsi_read_cap = scheme_gsi['ProvisionedThroughput']['ReadCapacityUnits'].to_i
                        scheme_gsi_write_cap = scheme_gsi['ProvisionedThroughput']['WriteCapacityUnits'].to_i

                        table_info.table[:global_secondary_indexes].each do |actual_gsi|
                            if actual_gsi[:index_name].eql? index_name
                                actual_gsi_read_cap = actual_gsi[:provisioned_throughput][:read_capacity_units]
                                actual_gsi_write_cap = actual_gsi[:provisioned_throughput][:write_capacity_units]
                                unless scheme_gsi_read_cap.eql?(actual_gsi_read_cap) and scheme_gsi_write_cap.eql?(actual_gsi_write_cap)
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
                        end
                    end
                    if new_gsis.empty?
                        puts "No update needed for #{table_name} GSI throughput capacity"
                    else
                        puts "Updating #{table_name} GSI throughput capacity"
                        params = {
                            :table_name => table_name,
                            :global_secondary_index_updates => new_gsis
                        }
                        dynamo_client.update_table(params)
                    end
                end

            else
                puts "Table #{table_name} does not exist.  Create it first!"
            end
        end
    end

    def cleanup_tables
        all_tables = @dynamodb_required_tables

        # Get all our expected tables
        expected_tables = Array.new
        all_tables.each do |table|
            expected_tables << table['TableName']
        end

        # Get all existing tables
        existing_tables = @dynamodb_tables

        # Make the diff between those.
        remaining_tables = existing_tables - expected_tables

        # Remove all tables that are remaining
        remaining_tables.each do |table_name|
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
                    delete_table(table_name)

                    # Sleep for N seconds so that we give AWS some time to create the table
                    sleep ENV['DYNAMODB_SLEEP_INTERVAL'].to_f
                end
            end
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
            tables_json = open(ENV['API_TABLE_RESOURCE']) { |f| f.read }
            api_tables = JSON.load(tables_json)
        rescue
            raise "JSON file #{ENV['API_TABLE_RESOURCE']} could not properly be read. Please make sure your source is accurate."
        end

        unless table_name.nil?
            api_tables.each do |table_definition|
                if table_definition['TableName'] == table_name
                    return table_definition
                end
            end
        end
        # If not specified, return all tables
        api_tables
    end
end
