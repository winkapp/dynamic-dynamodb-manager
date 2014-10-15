require_relative "../../spec/spec_helper.rb"

describe DynamicDynamoDBManager do

  before do
    @manager = DynamicDynamoDBManager.new
    puts "Creating all dynamoDB tables from an API list."
    @manager.create_dynamodb_tables
  end

  it 'returns a list of created tables' do
    expect(@manager.collections.include?('Sessions')).to eq(true)
  end

  after do
    tables = @manager.get_api_tables
    tables.each { |t|
      params = { table_name: t['TableName'] }
      puts "Deleting table " + t['TableName'] + "."
      @manager.dynamo_client.delete_table(params)
    }
  end

end