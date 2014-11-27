require_relative "../../spec/spec_helper.rb"
require 'pp'

describe DynamicDynamoDBManager do

  before do
    @manager = DynamicDynamoDBManager.new
  end

  it 'wrote a config file with all tables' do
    table_names = Array.new
    tables = @manager.get_all_required_tables
    tables.each do |table|
      table_names << table['TableName']
    end

    @manager.write_dynamic_dynamodb_config('/tmp/testing.cnf')
    File.open("/tmp/testing.cnf") do |f|
      f.each_line do |line|
        if line =~ /\[table/
          line.gsub! '[table: ^', ''
          line.gsub! '$]', ''
          line.delete!("\n")
          puts "Found table: #{line}"
          expect(table_names.include?(line)).to eq(true)
        end
      end
    end
  end

end