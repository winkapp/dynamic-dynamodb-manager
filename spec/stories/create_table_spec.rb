require_relative "../../spec/spec_helper.rb"

describe DynamicDynamoDBManager do

  before do
    @manager = DynamicDynamoDBManager.new

    new_table_params = { attribute_definitions: [ { attribute_name: 'something', attribute_type: 'S' } ],
                         key_schema: [ { attribute_name: 'something', key_type: 'HASH' } ],
                         provisioned_throughput: { read_capacity_units: 10, write_capacity_units: 5 },
                         table_name: 'some-random-collection-one' }

    @manager.dynamo_client.create_table(new_table_params)
  end

  it 'returns a list of collections' do
    expect(@manager.get_all_tables(true).include?('some-random-collection-one')).to eq(true)
  end

  after do
    params = { table_name: 'some-random-collection-one' }
    @manager.dynamo_client.delete_table(params)
  end

end