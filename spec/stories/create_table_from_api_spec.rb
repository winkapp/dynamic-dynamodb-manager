require_relative "../../spec/spec_helper.rb"

describe DynamicDynamoDBManager do

  before do
    puts "Creating all dynamoDB tables from an API list. Use December to test a new year"
    Timecop.freeze Date.new(2014,12,24) do
      @manager = DynamicDynamoDBManager.new
      @manager.get_all_required_tables(true)
      @manager.get_all_tables(true)
      @manager.create_dynamodb_tables
    end

  end

  it 'returns a list of created tables' do
    Timecop.freeze Date.new(2014,12,24) do
      # Refresh tables
      @manager.get_all_tables(true)
      # No rotation has no timestamp
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

      # Daily with rotate 2 means 1 day ahead and 2 behind
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20141225")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20141224")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20141223")).to eq(true)

      # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
      # in the future.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20141229")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20141222")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20141215")).to eq(true)

      # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20150101")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20141001")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20141101")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20141201")).to eq(true)

      # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20141225")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20141224")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20141223")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20141222")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20141221")).to eq(true)

    end
  end

  it 'sets the throughput to values that are cost-effective' do
    Timecop.freeze Date.new(2014,12,24) do
      # Refresh tables
      # Refresh tables
      @manager.get_all_tables(true)
      tables = @manager.get_all_required_tables(true)

      # Daily rotation for 20141224, and 20141225 should be set higher than any other table for the same prefix
      tables.each do | table |
        if table['TableName'] === "development.daily-purge2.20141224"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.daily-purge2.20141225"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end

        # weekly rotation with date 20141222 should be set higher than any other table for the same prefix.
        # the week after, 20141229 should be set lower
        if table['TableName'] === "development.weekly-purge2.20141222"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.weekly-purge2.20141229"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('30')
        end
        # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
        # the month after, 20150101 should be set lower
        if table['TableName'] === "development.monthly-purge4.20141201"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.monthly-purge4.20150101"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('30')
        end
      end
    end

    Timecop.freeze Date.new(2014,12,28) do
      # Refresh tables
      # Refresh tables
      @manager.get_all_tables(true)
      tables = @manager.get_all_required_tables(true)
      tables.each do | table |
        # Daily rotation for 20141228, and 20141229 should be set higher than any other table for the same prefix
        if table['TableName'] === "development.daily-purge2.20141228"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.daily-purge2.20141229"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        # weekly rotation with date 20141222 should be set higher than any other table for the same prefix.
        # the week after, 20141229 should also be set higher
        if table['TableName'] === "development.weekly-purge2.20141222"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.weekly-purge2.20141229"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
        # the month after, 20150101 should be set lower
        if table['TableName'] === "development.monthly-purge4.20141201"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.monthly-purge4.20150101"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('30')
        end
      end
    end

    Timecop.freeze Date.new(2014,12,31) do
      # Refresh tables
      # Refresh tables
      @manager.get_all_tables(true)
      tables = @manager.get_all_required_tables(true)
      tables.each do | table |
        # Daily rotation for 20141231, and 20150101 should be set higher than any other table for the same prefix
        if table['TableName'] === "development.daily-purge2.20141231"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.daily-purge2.20150101"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        # weekly rotation with date 20141229 should be set higher than any other table for the same prefix.
        # the week after, 20150105 should be set lower
        if table['TableName'] === "development.weekly-purge2.20141229"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.weekly-purge2.20150105"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('30')
        end
        # monthly rotation with date 20141201 should be set higher than any other table for the same prefix.
        # the month after, 20150101 should also be set higher
        if table['TableName'] === "development.monthly-purge4.20141201"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
        if table['TableName'] === "development.monthly-purge4.20150101"
          expect(table['Properties']['ProvisionedThroughput']['WriteCapacityUnits']).to eq('600')
        end
      end
    end
  end

  it 'successfully cleans up old tables' do
    Timecop.freeze Date.new(2014,9,1) do
      puts "Creating all dynamoDB tables from an API list but with an older date"
      # Refresh all tables
      @manager.get_all_tables(true)
      # Refresh all tables
      @manager.get_all_required_tables(true)
      # create some old tables
      @manager.create_dynamodb_tables

      # Verify we created the tables
      puts "Checking if all tables of that date were created"

      tables = @manager.get_all_tables(true)
      # No rotation has no timestamp
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

      # Daily with rotate 2 means 1 day ahead and 2 behind
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140902")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140831")).to eq(true)

      # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
      # in the future.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140908")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140825")).to eq(true)

      # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140601")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140701")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140801")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20141001")).to eq(true)

      # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140902")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140831")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140830")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140829")).to eq(true)
    end

    # Set time to a newer data
    Timecop.freeze Date.new(2014,12,24) do
      # Refresh all tables
      @manager.get_all_required_tables(true)
      # Refresh all tables
      @manager.get_all_tables(true)
      # Now we cleanup the tables so that only the tables of today remain
      puts "Cleaning up unnecessary tables"
      @manager.cleanup_tables
      # No rotation has no timestamp
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

      # Daily with rotate 2 means 1 day ahead and 2 behind
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140902")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140901")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-purge2.20140831")).to eq(false)

      # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
      # in the future.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140908")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140901")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".weekly-purge2.20140825")).to eq(false)

      # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140501")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140601")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140701")).to eq(false)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".monthly-purge4.20140801")).to eq(false)

      # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140902")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140901")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140831")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140830")).to eq(true)
      expect(@manager.get_all_tables.include?(ENV['RACK_ENV']+".daily-nopurge.20140829")).to eq(true)
    end
  end

  it 'returns a an empty list after deleting all tables' do
    Timecop.freeze Date.new(2014,12,24) do
      tables = @manager.get_all_required_tables(true)
      tables.each { |t|
        params = { table_name: t['TableName'] }
        puts "Deleting table " + t['TableName'] + "."
        @manager.dynamo_client.delete_table(params)
      }
      tables.each do | table |
        expect(@manager.get_all_tables(true).include?(table['TableName'])).to eq(false)
      end
    end
  end

end