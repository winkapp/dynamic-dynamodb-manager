class DynamicDynamoDBManager

  attr_reader :dynamo_client

  def initialize(config = {})
    AWS.config(config[:aws_config])
    @dynamo_client = AWS::DynamoDB::Client.new(:api_version => '2012-08-10')
  end

  def collections
    dynamo_client.list_tables[:table_names]
  end

  def get_tables
    tables = open("http://rest.mollom.com/v1/system/tables") { |f| f.read }
    JSON.load(tables)
  end

end