require_relative '../../spec/spec_helper.rb'


describe DynamicDynamoDBManager do

    before do
        @manager = DynamicDynamoDBManager.new
        new_table_params = {
            attribute_definitions: [
                {
                    attribute_name: 'something',
                    attribute_type: 'S'
                },
                {
                    attribute_name: 'Timestamp',
                    attribute_type: 'N'
                }
            ],
            key_schema: [
                {
                    attribute_name: 'something',
                    key_type: 'HASH'
                },
                {
                    attribute_name: 'Timestamp',
                    key_type: 'RANGE'
                }
            ],
            local_secondary_indexes: [
                {
                    index_name: 'TimestampIndex',
                    key_schema: [
                        {
                            attribute_name: 'something',
                            key_type: 'HASH'
                        },
                        {
                            attribute_name: 'Timestamp',
                            key_type: 'RANGE'
                        }
                    ],
                    projection: {
                        projection_type: 'ALL'
                    }
                }
            ],
            global_secondary_indexes: [
                {
                    index_name: 'something',
                    key_schema: [
                        {
                            attribute_name: 'something',
                            key_type: 'HASH'
                        },
                        {
                            attribute_name: 'Timestamp',
                            key_type: 'RANGE'
                        }
                    ],
                    projection: {
                        projection_type: 'ALL'
                    },
                    provisioned_throughput: {
                        read_capacity_units: 10,
                        write_capacity_units: 5
                    }
                }
            ],
            stream_specification: {
                stream_enabled: true,
                stream_view_type: 'NEW_IMAGE'
            },
            provisioned_throughput: {
                read_capacity_units: 10,
                write_capacity_units: 5
            },
            table_name: 'some-random-collection-one'
        }
        @manager.dynamo_client.create_table(new_table_params)
    end

    it 'returns a list of collections' do
        expect(@manager.get_all_tables(true, true)).to include('some-random-collection-one')
    end

    after do
        @manager.delete_table('some-random-collection-one')
    end

end
