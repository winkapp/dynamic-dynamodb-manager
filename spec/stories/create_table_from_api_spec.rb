require_relative "../../spec/spec_helper.rb"

describe DynamicDynamoDBManager do

  before do
    @manager = DynamicDynamoDBManager.new
    puts "Creating all dynamoDB tables from an API list."
    @manager.create_dynamodb_tables
  end

  it 'returns a list of created tables' do
    tables = @manager.get_all_tables
    tables.each do | table |
      expect(@manager.collections.include?(table['TableName'])).to eq(true)
    end
  end

  it 'returns a an empty list after deleting all tables' do
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