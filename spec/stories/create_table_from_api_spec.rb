require_relative '../../spec/spec_helper.rb'

rack_env = ENV['RACK_ENV']


describe DynamicDynamoDBManager do

    before do
        puts 'Creating all dynamoDB tables from an API list. Use December to test a new year'
        Timecop.freeze Date.new(2014, 12, 24) do
            @manager = DynamicDynamoDBManager.new  # (verbose: true)
            @manager.get_all_required_tables(true)
            @manager.get_all_tables(true)
            @manager.create_tables
        end

    end

    it 'returns a list of created tables' do
        Timecop.freeze Date.new(2014, 12, 24) do
            # Refresh tables
            tables = @manager.get_all_tables(true)
            # No rotation has no timestamp
            expect(tables).to include("#{rack_env}.norotation")

            # Daily with rotate 2 means 1 day ahead and 2 behind
            expect(tables).to include("#{rack_env}.daily-purge2.20141225")
            expect(tables).to include("#{rack_env}.daily-purge2.20141224")
            expect(tables).to include("#{rack_env}.daily-purge2.20141223")

            # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
            # in the future.
            expect(tables).to include("#{rack_env}.weekly-purge2.20141229")
            expect(tables).to include("#{rack_env}.weekly-purge2.20141222")
            expect(tables).to include("#{rack_env}.weekly-purge2.20141215")

            # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
            expect(tables).to include("#{rack_env}.monthly-purge4.20150101")
            expect(tables).to include("#{rack_env}.monthly-purge4.20140901")
            expect(tables).to include("#{rack_env}.monthly-purge4.20141001")
            expect(tables).to include("#{rack_env}.monthly-purge4.20141101")
            expect(tables).to include("#{rack_env}.monthly-purge4.20141201")

            # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
            expect(tables).to include("#{rack_env}.daily-nopurge.20141225")
            expect(tables).to include("#{rack_env}.daily-nopurge.20141224")
            expect(tables).to include("#{rack_env}.daily-nopurge.20141223")
            expect(tables).to include("#{rack_env}.daily-nopurge.20141222")
            expect(tables).to include("#{rack_env}.daily-nopurge.20141221")

        end
    end

    it 'sets primary and secondary redis keys' do
        Timecop.freeze Date.new(2014, 12, 24) do
            # Refresh tables
            @manager.get_all_tables(true)
            tables = @manager.get_all_required_tables(true)

            primaries = %W(#{rack_env}.daily-purge2.20141224 #{rack_env}.daily-nopurge.20141224 #{rack_env}.weekly-purge2.20141222 #{rack_env}.monthly-purge4.20141201)
            secondaries = %W(#{rack_env}.daily-purge2.20141223 #{rack_env}.daily-nopurge.20141223 #{rack_env}.weekly-purge2.20141215 #{rack_env}.monthly-purge4.20141101)
            tables.each do |table|
                table_name = table['TableName']
                if primaries.include?(table_name)
                    expect(table).to include('PRIMARY_DYNAMODB_TABLE')
                    expect(table['PRIMARY_DYNAMODB_TABLE']).to be true
                    expect(table).to_not include('SECONDARY_DYNAMODB_TABLE')
                elsif secondaries.include?(table_name)
                    expect(table).to include('SECONDARY_DYNAMODB_TABLE')
                    expect(table['SECONDARY_DYNAMODB_TABLE']).to be true
                    expect(table).to_not include('PRIMARY_DYNAMODB_TABLE')
                else
                    if table_name.eql?("#{rack_env}.norotation")
                        expect(table).to include('PRIMARY_DYNAMODB_TABLE')
                        expect(table['PRIMARY_DYNAMODB_TABLE']).to be true
                        expect(table).to include('SECONDARY_DYNAMODB_TABLE')
                        expect(table['SECONDARY_DYNAMODB_TABLE']).to be true
                    else
                        expect(table).to_not include('PRIMARY_DYNAMODB_TABLE')
                        expect(table).to_not include('SECONDARY_DYNAMODB_TABLE')
                    end
                end
            end
        end
    end

    it 'sets the throughput to values that are cost-effective' do
        Timecop.freeze Date.new(2014, 12, 24) do
            # Refresh tables
            @manager.get_all_tables(true)
            tables = @manager.get_all_required_tables(true)

            # Daily rotation for 20141224, and 20141225 should be set higher than any other table for the same prefix
            #
            # Weekly rotation with date 20141222 should be set higher than any other table for the same prefix.
            # the week after, 20141229 should be set lower
            #
            # Monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
            # the month after, 20150101 should be set lower
            high_tp = %W(#{rack_env}.daily-purge2.20141224 #{rack_env}.daily-purge2.20141225 #{rack_env}.weekly-purge2.20141222 #{rack_env}.monthly-purge4.20141201)
            low_tp = %W(#{rack_env}.daily-purge2.20141223 #{rack_env}.weekly-purge2.20141215 #{rack_env}.weekly-purge2.20141229 #{rack_env}.monthly-purge4.20140901 #{rack_env}.monthly-purge4.20141001 #{rack_env}.monthly-purge4.20141101 #{rack_env}.monthly-purge4.20150101)

            tables.each do |table|
                table_name = table['TableName']
                write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']

                if low_tp.include?(table_name)
                    expect(read_cap).to eq(5)
                    expect(write_cap).to eq(30)
                elsif high_tp.include?(table_name)
                    expect(read_cap).to eq(50)
                    expect(write_cap).to eq(600)
                end
            end
        end

        Timecop.freeze Date.new(2014, 12, 28) do
            # Refresh tables
            @manager.get_all_tables(true)
            tables = @manager.get_all_required_tables(true)

            # Daily rotation for 20141228, and 20141229 should be set higher than any other table for the same prefix
            #
            # weekly rotation with date 20141222 should be set higher than any other table for the same prefix.
            # the week after, 20141229 should also be set higher
            #
            # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
            # the month after, 20150101 should be set lower
            low_tp = %W(#{rack_env}.daily-purge2.20141227 #{rack_env}.weekly-purge2.20141215 #{rack_env}.monthly-purge4.20140901 #{rack_env}.monthly-purge4.20141001 #{rack_env}.monthly-purge4.20141101 #{rack_env}.monthly-purge4.20150101)
            high_tp = %W(#{rack_env}.daily-purge2.20141228 #{rack_env}.daily-purge2.20141229 #{rack_env}.weekly-purge2.20141222 #{rack_env}.weekly-purge2.20141229 #{rack_env}.monthly-purge4.20141201)

            tables.each do |table|
                table_name = table['TableName']
                write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']

                if low_tp.include?(table_name)
                    expect(read_cap).to eq(5)
                    expect(write_cap).to eq(30)
                elsif high_tp.include?(table_name)
                    expect(read_cap).to eq(50)
                    expect(write_cap).to eq(600)
                end
            end
        end

        Timecop.freeze Date.new(2014, 12, 31) do
            # Refresh tables
            @manager.get_all_tables(true)
            tables = @manager.get_all_required_tables(true)

            # Daily rotation for 20141231, and 20150101 should be set higher than any other table for the same prefix
            #
            # weekly rotation with date 20141229 should be set higher than any other table for the same prefix.
            # the week after, 20150105 should be set lower
            #
            # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
            # the month after, 20150101 should also be set higher
            low_tp = %W(#{rack_env}.daily-purge2.20141230 #{rack_env}.weekly-purge2.20141222 #{rack_env}.weekly-purge2.20150105 #{rack_env}.monthly-purge4.20140901 #{rack_env}.monthly-purge4.20141001 #{rack_env}.monthly-purge4.20141101)
            high_tp = %W(#{rack_env}.daily-purge2.20141231 #{rack_env}.daily-purge2.20150101 #{rack_env}.weekly-purge2.20141229 #{rack_env}.monthly-purge4.20141201 #{rack_env}.monthly-purge4.20150101)

            tables.each do |table|
                table_name = table['TableName']
                write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']

                if low_tp.include?(table_name)
                    expect(read_cap).to eq(5)
                    expect(write_cap).to eq(30)
                elsif high_tp.include?(table_name)
                    expect(read_cap).to eq(50)
                    expect(write_cap).to eq(600)
                end
            end
        end
    end

    it 'Updates the throughput to correct values' do
        Timecop.freeze Date.new(2014, 12, 24) do
            # Refresh all tables
            @manager.get_all_tables(true)
            tables = @manager.get_all_required_tables(true)

            tables.each do |table|
                table_name = table['TableName']
                table_info = @manager.dynamo_client.describe_table({:table_name => table_name})

                if table['Properties'].include? 'OutdatedTableProvisionedThroughput'
                    read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']
                    write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                    old_read_cap = table['Properties']['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                    old_write_cap = table['Properties']['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']
                    actual_read_cap = table_info.table[:provisioned_throughput][:read_capacity_units]
                    actual_write_cap = table_info.table[:provisioned_throughput][:write_capacity_units]

                    # Daily rotation for 20141224, and 20141225 should be set higher than any other table for the same prefix
                    if table_name === "#{rack_env}.daily-purge2.20141223"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20141224"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20141225"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end

                    # weekly rotation with date 20141222 should be set higher than any other table for the same prefix.
                    # the week after, 20141229 should be set lower
                    if table_name === "#{rack_env}.weekly-purge2.20141215"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20141222"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20141229"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end

                    # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
                    # the month after, 20150101 should be set lower
                    if table_name === "#{rack_env}.monthly-purge4.20141101"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20141201"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20150101"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                end

                if table['Properties'].include? 'GlobalSecondaryIndexes'
                    if table['Properties']['GlobalSecondaryIndexes'][0].include? 'OutdatedTableProvisionedThroughput'
                        gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['ReadCapacityUnits']
                        gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['WriteCapacityUnits']
                        old_gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                        old_gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']
                        actual_gsi_read_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:read_capacity_units]
                        actual_gsi_write_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:write_capacity_units]

                        # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
                        # the month after, 20150101 should be set lower
                        if table_name === "#{rack_env}.monthly-purge4.20141101"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20141201"
                            expect(actual_gsi_read_cap).to eq(gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20150101"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                    end
                end
            end
        end

        Timecop.freeze Date.new(2014, 12, 31) do
            # Refresh all tables
            @manager.get_all_required_tables(true)
            # Refresh all tables
            @manager.get_all_tables(true)

            # create some tables
            @manager.create_tables

            # Now we update the tables throughput
            puts 'Updating throughput on tables'
            @manager.update_tables

            # Refresh all tables
            tables = @manager.get_all_required_tables(true)

            tables.each do |table|
                table_name = table['TableName']
                table_info = @manager.dynamo_client.describe_table({:table_name => table_name})

                if table['Properties'].include? 'OutdatedTableProvisionedThroughput'
                    read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']
                    write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                    old_read_cap = table['Properties']['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                    old_write_cap = table['Properties']['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']
                    actual_read_cap = table_info.table[:provisioned_throughput][:read_capacity_units]
                    actual_write_cap = table_info.table[:provisioned_throughput][:write_capacity_units]

                    # Daily rotation for 20141231, and 20150101 should be set higher than any other table for the same prefix
                    if table_name === "#{rack_env}.daily-purge2.20141230"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20141231"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20150101"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end

                    # weekly rotation with date 20141229 should be set higher than any other table for the same prefix.
                    # the week after, 20150105 should be set lower
                    if table_name === "#{rack_env}.weekly-purge2.20141222"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20141229"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20150105"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end

                    # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
                    # the month after, 20150101 should also be set higher
                    if table_name === "#{rack_env}.monthly-purge4.20141101"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20141201"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20150101"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                end
                if table['Properties'].include? 'GlobalSecondaryIndexes'
                    if table['Properties']['GlobalSecondaryIndexes'][0].include? 'OutdatedTableProvisionedThroughput'
                        gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['ReadCapacityUnits']
                        gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['WriteCapacityUnits']
                        old_gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                        old_gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']
                        actual_gsi_read_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:read_capacity_units]
                        actual_gsi_write_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:write_capacity_units]

                        # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
                        # the month after, 20150101 should also be set higher
                        if table_name === "#{rack_env}.monthly-purge4.20141101"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20141201"
                            expect(actual_gsi_read_cap).to eq(gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20150101"
                            expect(actual_gsi_read_cap).to eq(gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(gsi_write_cap)
                        end
                    end
                end
            end
        end

        Timecop.freeze Date.new(2015, 1, 1) do
            # Refresh all tables
            @manager.get_all_required_tables(true)
            # Refresh all tables
            @manager.get_all_tables(true)

            # create some tables
            @manager.create_tables

            # Now we update the tables throughput
            puts 'Updating throughput on tables'
            @manager.update_tables

            # Refresh all tables
            tables = @manager.get_all_required_tables(true)

            tables.each do |table|
                table_name = table['TableName']
                table_info = @manager.dynamo_client.describe_table({:table_name => table_name})

                if table['Properties'].include? 'OutdatedTableProvisionedThroughput'
                    read_cap = table['Properties']['ProvisionedThroughput']['ReadCapacityUnits']
                    write_cap = table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']
                    old_read_cap = table['Properties']['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                    old_write_cap = table['Properties']['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']
                    actual_read_cap = table_info.table[:provisioned_throughput][:read_capacity_units]
                    actual_write_cap = table_info.table[:provisioned_throughput][:write_capacity_units]

                    # Daily rotation for 20150101, 20150101 and 20150102 should be set higher than any other table for the same prefix
                    if table_name === "#{rack_env}.daily-purge2.20141231"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20150101"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.daily-purge2.20150102"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end

                    # weekly rotation with date 20141229 should be set higher than any other table for the same prefix.
                    # the week after, 20150105 should be set lower
                    if table_name === "#{rack_env}.weekly-purge2.20141222"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20141229"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.weekly-purge2.20150105"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end

                    # monthly rotation with date 20150101 should be set higher than any other table for the same prefix.
                    # the month after, 20150201 should also be set lower
                    if table_name === "#{rack_env}.monthly-purge4.20141101"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20141201"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20150101"
                        expect(actual_read_cap).to eq(read_cap)
                        expect(actual_write_cap).to eq(write_cap)
                    end
                    if table_name === "#{rack_env}.monthly-purge4.20150201"
                        expect(actual_read_cap).to eq(old_read_cap)
                        expect(actual_write_cap).to eq(old_write_cap)
                    end
                end

                if table['Properties'].include? 'GlobalSecondaryIndexes'
                    if table['Properties']['GlobalSecondaryIndexes'][0].include? 'OutdatedTableProvisionedThroughput'
                        gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['ReadCapacityUnits']
                        gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['ProvisionedThroughput']['WriteCapacityUnits']
                        old_gsi_read_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['ReadCapacityUnits']
                        old_gsi_write_cap = table['Properties']['GlobalSecondaryIndexes'][0]['OutdatedTableProvisionedThroughput']['WriteCapacityUnits']

                        actual_gsi_read_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:read_capacity_units]
                        actual_gsi_write_cap = table_info.table[:global_secondary_indexes][0][:provisioned_throughput][:write_capacity_units]

                        # monthly rotation with date 20150101 should be set higher than any other table for the same prefix.
                        # the month after, 20150201 should also be set lower
                        if table_name === "#{rack_env}.monthly-purge4.20141101"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20141201"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20150101"
                            expect(actual_gsi_read_cap).to eq(gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(gsi_write_cap)
                        end
                        if table_name === "#{rack_env}.monthly-purge4.20150201"
                            expect(actual_gsi_read_cap).to eq(old_gsi_read_cap)
                            expect(actual_gsi_write_cap).to eq(old_gsi_write_cap)
                        end
                    end
                end
            end
        end
    end


    it 'successfully cleans up old tables' do

        Timecop.freeze Date.new(2014, 9, 1) do
            puts 'Creating all dynamoDB tables from an API list but with an older date'
            # Refresh all tables
            @manager.get_all_tables(true)
            # Refresh all tables
            @manager.get_all_required_tables(true)
            # create some old tables
            @manager.create_tables

            # Verify we created the tables
            puts 'Checking if all tables of that date were created'

            tables = @manager.get_all_tables(true)
            # No rotation has no timestamp
            expect(tables).to include("#{rack_env}.norotation")
            expect(tables).to include("#{rack_env}.norotation")

            # Daily with rotate 2 means 1 day ahead and 2 behind
            expect(tables).to include("#{rack_env}.daily-purge2.20140902")
            expect(tables).to include("#{rack_env}.daily-purge2.20140901")
            expect(tables).to include("#{rack_env}.daily-purge2.20140831")

            # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
            # in the future.
            expect(tables).to include("#{rack_env}.weekly-purge2.20140908")
            expect(tables).to include("#{rack_env}.weekly-purge2.20140901")
            expect(tables).to include("#{rack_env}.weekly-purge2.20140825")

            # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
            expect(tables).to include("#{rack_env}.monthly-purge4.20140601")
            expect(tables).to include("#{rack_env}.monthly-purge4.20140701")
            expect(tables).to include("#{rack_env}.monthly-purge4.20140801")
            expect(tables).to include("#{rack_env}.monthly-purge4.20140901")
            expect(tables).to include("#{rack_env}.monthly-purge4.20141001")

            # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
            expect(tables).to include("#{rack_env}.daily-nopurge.20140902")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140901")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140831")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140830")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140829")
        end

        # Set time to a newer data
        Timecop.freeze Date.new(2014, 12, 24) do
            # Refresh all tables
            @manager.get_all_required_tables(true)
            # Refresh all tables
            @manager.get_all_tables(true)
            # Now we cleanup the tables so that only the tables of today remain
            puts 'Cleaning up unnecessary tables'
            @manager.cleanup_tables

            tables = @manager.get_all_tables(true)
            # No rotation has no timestamp
            expect(tables).to include("#{rack_env}.norotation")

            # Daily with rotate 2 means 1 day ahead and 2 behind
            # puts tables
            expect(tables).to_not include("#{rack_env}.daily-purge2.20140902")
            expect(tables).to_not include("#{rack_env}.daily-purge2.20140901")
            expect(tables).to_not include("#{rack_env}.daily-purge2.20140831")

            # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
            # in the future.
            expect(tables).to_not include("#{rack_env}.weekly-purge2.20140908")
            expect(tables).to_not include("#{rack_env}.weekly-purge2.20140901")
            expect(tables).to_not include("#{rack_env}.weekly-purge2.20140825")

            # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
            expect(tables).to_not include("#{rack_env}.monthly-purge4.20140501")
            expect(tables).to_not include("#{rack_env}.monthly-purge4.20140601")
            expect(tables).to_not include("#{rack_env}.monthly-purge4.20140701")
            expect(tables).to_not include("#{rack_env}.monthly-purge4.20140801")

            # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
            expect(tables).to include("#{rack_env}.daily-nopurge.20140902")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140901")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140831")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140830")
            expect(tables).to include("#{rack_env}.daily-nopurge.20140829")
        end
    end

    it 'returns an empty list after deleting all tables' do
        Timecop.freeze Date.new(2014, 12, 24) do
            tables = @manager.get_all_required_tables(true)
            tables.each do |t|
                @manager.delete_table(t['TableName'])
            end
            all_tables = @manager.get_all_tables(true)
            tables.each do |table|
                expect(all_tables).to_not include(table['TableName'])
            end
        end
    end

end
