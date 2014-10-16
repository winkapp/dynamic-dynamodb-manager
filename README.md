[![Build Status](https://travis-ci.org/Mollom/dynamic-dynamodb-manager.svg?branch=master)](https://travis-ci.org/Mollom/dynamic-dynamodb-manager)

# Dynamic DynamoDB Table Manager

This repository contains a Ruby client library that is primarily used for Mollom to generate new tables on a 
weekly or daily scheme using a predefined pattern. It also includes a command line tool that can be run via any
 *nix-like terminal.

## Installation

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
dynamic-dynamodb-manager-cli rotate '/tmp/testing.conf' --no-deletion
```
This command will take the API resource, consume it and make sure that the tables in your API resource exist. If they do not exist it will create it. It will expand the list of tables to create based on the rotation scheme. The tables that do not exist in the rotation scheme will be dropped. 
Add the option --no-table-drop to the command line to not delete any tables.
This command will also write the Dynamic DynamoDB configuration file. There is an ERB that we will update to allow more options. For now, this is sufficient to what we need. 

Note: By default it does NOT purge the old tables. It will create new ones.

```
dynamic-dynamodb-manager-cli rotate '/tmp/testing.conf' --deletion
```
Use above command when you are sure you can afford deletion of tables.

## Use environment variables as your friend

List of environment variables that can be changed

* DYNAMODB_ENDPOINT=localhost
Where to go to for Dynamo. Use rake fake_dynamo to spin up a local version of dynamodb to test against.
* DYNAMODB_PORT=4567
DynamoDB port
* AWS_ACCESS_KEY='00000'
AWS Access key to access your DynamoDB instance
* AWS_SECRET_ACCESS_KEY='00000'
AWS Secret Access key to access your DynamoDB instance
* DYNAMODB_API_VERSION='2012-08-10'
The version of DynamoDB API you want to use. Default is latest as of this writing.
* DYNAMODB_USE_SSL=0
I'm not entirely sure if this works properly. But it is possible.
* API_TABLE_RESOURCE='http://testing.com/v1/system/tables'
The source of your json feed. This could either be a local file or a remote file. We use S3 files that we read. 
If the file can't be read. The application will error out.
* BUGSNAG_APIKEY=
The Gem supports BUGSNAG. The only thing you need to do is to add your BUGSNAG key to the environment variables
and it will help you figure out where it fails and if it fails.
    
```
API_TABLE_RESOURCE=/tmp/tables.json dynamic-dynamodb-manager-cli rotate '/tmp/testing.conf' --deletion
```
This is an example on how you could use this tool with multiple variations. We use this with CloudFormation where we
can setup Environment Variables per Stack we spin up.

Note: If you installed via bundle
```
bundle exec dynamic-dynamodb-manager-cli
```

## API structure to consume.

The following example is what this tool expects in order to create the tables automatically. It will read it (see API_TABLE_RESOURCE env variable) and use this to create tables and or write the appropriate config files.

RotationScheme accepts the following values: daily, weekly, monthly.

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
