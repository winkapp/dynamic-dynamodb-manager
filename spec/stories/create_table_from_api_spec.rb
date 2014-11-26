require_relative "../../spec/spec_helper.rb"

describe DynamicDynamoDBManager do

  before do
    @manager = DynamicDynamoDBManager.new
    puts "Creating all dynamoDB tables from an API list. Use December to test a new year"
    Timecop.freeze Date.new(2014,12,24) do
      @manager.create_dynamodb_tables
    end
    # No rotation has no timestamp
    expect(@manager.collections.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

    # Daily with rotate 2 means 1 day ahead and 2 behind
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20141225")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20141224")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20141223")).to eq(true)

    # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
    # in the future.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20141229")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20141222")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20141215")).to eq(true)

    # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20150124")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140924")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20141024")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20141124")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20141224")).to eq(true)

    # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20141225")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20141224")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20141223")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20141222")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20141221")).to eq(true)
  end

  it 'returns a list of created tables' do
    Timecop.freeze Date.new(2014,12,24) do
      tables = @manager.get_all_tables
      tables.each do | table |
        expect(@manager.collections.include?(table['TableName'])).to eq(true)
      end
    end
  end

  it 'successfully cleans up old tables' do
    # create some old tables
    # run the cleanup command
    Timecop.freeze Date.new(2014,9,1) do
      puts "Creating all dynamoDB tables from an API list but with an older date"
      @manager.create_dynamodb_tables
    end

    # Verify we created the tables
    puts "Checking if all tables of that date were created"
    # No rotation has no timestamp
    expect(@manager.collections.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

    # Daily with rotate 2 means 1 day ahead and 2 behind
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140902")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140901")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140831")).to eq(true)

    # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
    # in the future.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140908")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140901")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140825")).to eq(true)

    # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140601")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140701")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140801")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140901")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20141001")).to eq(true)

    # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140902")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140901")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140831")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140830")).to eq(true)
    expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140829")).to eq(true)

    Timecop.freeze Date.new(2014,12,24) do
      # Now we cleanup the tables so that only the tables of today remain
      puts "Cleaning up unnecessary tables"
      @manager.cleanup_tables
      # No rotation has no timestamp
      expect(@manager.collections.include?(ENV['RACK_ENV']+".norotation")).to eq(true)

      # Daily with rotate 2 means 1 day ahead and 2 behind
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140902")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140901")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-purge2.20140831")).to eq(false)

      # Weekly with rotate 2 means 1 week ahead and 2 behind. Starting on the next monday for the one
      # in the future.
      expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140908")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140901")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".weekly-purge2.20140825")).to eq(false)

      # Monthly with rotate 4 means 1 month ahead and 4 behind. Starting on the first day of the month.
      expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140601")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140701")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140801")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20140901")).to eq(false)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".monthly-purge4.20141001")).to eq(false)

      # daily with rotate 4 means 1 day ahead and 4 behind. The nopurge means they will not get deleted.
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140902")).to eq(true)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140901")).to eq(true)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140831")).to eq(true)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140830")).to eq(true)
      expect(@manager.collections.include?(ENV['RACK_ENV']+".daily-nopurge.20140829")).to eq(true)
    end
  end

  it 'returns a an empty list after deleting all tables' do
    Timecop.freeze Date.new(2014,12,24) do
      tables = @manager.get_all_tables
      tables.each { |t|
        params = { table_name: t['TableName'] }
        puts "Deleting table " + t['TableName'] + "."
        @manager.dynamo_client.delete_table(params)
      }
      tables.each do | table |
        expect(@manager.collections.include?(table['TableName'])).to eq(false)
      end
    end
  end

end