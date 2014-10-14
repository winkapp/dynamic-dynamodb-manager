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

Note: If you installed via bundle
```
bundle exec dynamic-dynamodb-manager-cli
```

@todo

## Related Projects

* [Mollom](https://github.com/mollom/backend)
