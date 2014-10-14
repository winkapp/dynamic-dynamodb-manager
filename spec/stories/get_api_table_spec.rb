require_relative "../../spec/spec_helper.rb"
require 'pp'

describe DynamicDynamoDBManager do


  before do
    aws_config = { :dynamo_db_endpoint => 'localhost',
                   :dynamo_db_port     => 4567,
                   :access_key_id      => '00000',
                   :secret_access_key  => '00000',
                   :api_version        => '2012-08-10',
                   :use_ssl            => false }

    @manager = DynamicDynamoDBManager.new(aws_config: aws_config)

  end

  it 'returns a list of tables' do
    tables = @manager.get_tables
    expect(tables[0]['table_name']).to eq ("sessions")
    expect(tables[0]['rotation_days']).to eq ("7")
    expect(tables[0]['purge_rotation']).to eq ("4")
    expect(tables[0]['min_read_capacity']).to eq ("200")
    expect(tables[1]['table_name']).to eq ("someothertable")
  end

end