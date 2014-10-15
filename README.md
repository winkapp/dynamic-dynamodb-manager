[![Build Status](https://travis-ci.org/Mollom/dynamic-dynamodb-manager.svg?branch=master)](https://travis-ci.org/Mollom/dynamic-dynamodb-manager)

# Dynamic DynamoDB Table Manager

This repository contains a Ruby client library that is primarily used for Mollom to generate new tables on a 
weekly or daily scheme using a predefined pattern. It also includes a command line tool that can be run via any
 *nix-like terminal.

## Installation

## Request creds from @todo

Append the following lines to your .netrc file.
```
@todo
```

In each environment you are running this GEM you will need the following environment variables:

    DYNAMODB_ENDPOINT=localhost
    DYNAMODB_PORT=4567
    AWS_ACCESS_KEY='00000'
    AWS_SECRET_ACCESS_KEY='00000'
    DYNAMODB_API_VERSION='2012-08-10'
    DYNAMODB_USE_SSL=0
    API_TABLE_RESOURCE='http://testing.com/v1/system/tables'
    BUGSNAG_APIKEY=
    
Without these environment variables, it will not be able to create your tables as the API_TABLE_RESOURCE does not exist in real life. It only exists in the testing world ;-)

## Install cli tool

```
git clone git@github.com:acquia/dynamic-dynamodb-manager.git
cd dynamic-dynamodb-manager
gem build dynamic-dynamodb-manager.gemspec
gem install dynamic-dynamodb-manager-0.0.1.gem
```

```
dynamic-dynamodb-manager-cli
```
Note: You may need to run *rbenv rehash* 


## Use this in an app

Add this to your Gemfile
```
gem 'dynamic-dynamodb-manager', :git => "git@github.com:acquia/dynamic-dynamodb-manager.git"

```

Then run bundle install.

@todo

## Usage

```
dynamic-dynamodb-manager-cli
```
This will give you an overview of the commands


```
dynamic-dynamodb-manager-cli write_config '/tmp/testing.conf'
```
This command will take your API and consume it to write the Dynamic DynamoDB configuration file. There is an ERB that we will update to allow more options. For now, this is sufficient to what we need. 

```
dynamic-dynamodb-manager-cli rotate '/tmp/testing.conf'
```
This command will take the API resource, consume it and make sure that the tables in your API resource exist. If they do not exist it will create it. It will expand the list of tables to create based on the rotation scheme. The tables that do not exist in the rotation scheme will be dropped. 
Add the option --no-table-drop to the command line to not delete any tables.


Note: If you installed via bundle
```
bundle exec dynamic-dynamodb-manager-cli
```

## API structure to consume.

The following example is what this tool expects in order to create the tables automatically. It will read it (see API_TABLE_RESOURCE env variable) and use this to create tables and or write the appropriate config files.

    [
        {
            "TableName" : "MyTable",
            "RotationScheme" : "daily",
            "PurgeRotation" : "4",
            "Properties" : {
                "AttributeDefinitions" : [
                    {
                        "AttributeName" : "MyTableId",
                        "AttributeType" : "S"
                    },
                    {
                        "AttributeName" : "Timestamp",
                        "AttributeType" : "N"
                    }
                ],
                "KeySchema" : [
                    {
                        "AttributeName" : "MyTableId",
                        "KeyType" : "HASH"
                    },
                    {
                        "AttributeName" : "Timestamp",
                        "KeyType" : "RANGE"
                    }
    
                ],
                "ProvisionedThroughput" : {
                    "ReadCapacityUnits" : "5",
                    "WriteCapacityUnits" : "5"
                }
            }
        }
    ]
@todo

## Related Projects

* [Mollom](https://github.com/mollom/backend)
