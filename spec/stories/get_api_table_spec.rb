require_relative "../../spec/spec_helper.rb"
require 'pp'

describe DynamicDynamoDBManager do


  before do
    @manager = DynamicDynamoDBManager.new
  end

  it 'returns a list of tables' do
    tables = @manager.get_all_tables
    expect(tables[0]['TableName']).to eq ("Sessions")
    expect(tables[0]['RotationScheme']).to eq ("daily")
    expect(tables[0]['PurgeRotation']).to eq ("4")
    expect(tables[1]['TableName']).to eq ("HttpHeaders")
  end

end