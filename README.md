
CircleCI Status: [![CircleCI](https://circleci.com/gh/winkapp/dynamic-dynamodb-manager/tree/master.svg?style=svg)](https://circleci.com/gh/winkapp/dynamic-dynamodb-manager/tree/master)
Docker Status: [![Docker Repository on Quay](https://quay.io/repository/winkapp/dynamic-dynamodb-manager/status?token=ca727edd-f884-48dd-aad2-0e822422cf34 "Docker Repository on Quay")](https://quay.io/repository/winkapp/dynamic-dynamodb-manager)

# Dynamic DynamoDB Table Manager

This repository contains a Ruby client library that is primarily used for Mollom to generate new tables on a
weekly or daily scheme using a predefined pattern. It also includes a command line tool that can be run via any
 *nix-like terminal.

It extends https://github.com/sebdah/dynamic-dynamodb by dynamically writing a config file that can be read by dynamic-dynamodb service.

## Installation

In each environment you are running this GEM you will need the following environment variables:

    DYNAMODB_ENDPOINT=localhost
    DYNAMODB_PORT=4567
    AWS_ACCESS_KEY='00000'
    AWS_SECRET_ACCESS_KEY='00000'
    DYNAMODB_USE_SSL=0
    API_TABLE_RESOURCE='spec/support/fixtures/tables.json'
    BUGSNAG_APIKEY=

Without these environment variables, it will not be able to create your tables as the API_TABLE_RESOURCE does not exist in real life. It only exists in the testing world

## Install cli tool

```
git clone https://github.com/winkapp/dynamic-dynamodb-manager.git
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
gem 'dynamic-dynamodb-manager', :git => "git@github.com:winkapp/dynamic-dynamodb-manager.git"

```

Then run bundle install.

## Usage

```
dynamic-dynamodb-manager-cli
```
This will give you an overview of the commands

```
dynamic-dynamodb-manager-cli rotate '/tmp/testing.conf' --no-deletion
```
This command will take the API resource, consume it and make sure that the tables in your API resource exist. If they do not exist it will create it. It will expand the list of tables to create based on the rotation scheme. The tables that do not exist in the rotation scheme will be dropped.
Add the option `--no-deletion` to the command line to not delete any tables.
This command will also write the Dynamic DynamoDB configuration file. There is an ERB that we will update to allow more options. For now, this is sufficient to what we need.

```
dynamic-dynamodb-manager-cli rotate --deletion
```
Use above command when you are sure you can afford deletion of tables and do not need a Dynamic DynamoDB config file.

## Use environment variables as your friend

List of environment variables that can be changed

* `DYNAMODB_ENDPOINT=localhost`
Where to go to for Dynamo. Use [Local DynamoDB](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html) to spin up a local version of dynamodb to test against.
* `DYNAMODB_PORT=4567`
DynamoDB port
* `AWS_ACCESS_KEY='00000'`
AWS Access key to access your DynamoDB instance
* `AWS_SECRET_ACCESS_KEY='00000'`
AWS Secret Access key to access your DynamoDB instance
* `AWS_REGION=us-east-1`
AWS Region
* `DYNAMODB_USE_SSL=0`
I'm not entirely sure if this works properly. But it is possible.
* `API_TABLE_RESOURCE='http://testing.com/v1/system/tables'`
The source of your json feed. This could either be a local file or a remote file. We use S3 files that we read.
If the file can't be read. The application will error out.
* `REDIS_URL='redis://USER:PASS@HOST:PORT'`
The URL of the Redis instance to update with the current and previous DynamoDB Table names.
For each table in the `API_TABLE_RESOURCE` json, the current month/week/day table name will be set as the value for key `DYNAMODB_PRIMARY_XXXX` (in hash: `env_override_hash`)
and the previous month/week/day table name will be set as the value for key `DYNAMODB_SECONDARY_XXXX` (*where `XXXX` is the upper-case table name with any non-word characters replaced with `_`'s*)
* `BUGSNAG_APIKEY=`
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

## Running tests
* Start up a [Local DynamoDB](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html)
* `bundle exec rspec spec/`


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
