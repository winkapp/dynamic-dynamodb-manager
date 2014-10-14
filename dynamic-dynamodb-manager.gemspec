require 'date'

Gem::Specification.new do |s|
  s.name        = 'dynamic-dynamodb-manager'
  s.version     = '0.0.1'
  s.date        = Date.today.to_s
  s.summary     = "Manages tables regarding DynamoDB and generates a new config for Dynamic DynamoDB"
  s.description = ""
  s.authors     = ["Nick Veenhof"]
  s.email       = 'nick.veenhof@acquia.com'
  s.files       = ["lib/dynamic_dynamodb_manager.rb"]
  s.homepage    = 'https://github.com/acquia/dynamic-dynamodb-manager'
  s.license     = 'GPLv2'

  s.executables << 'dynamic-dynamodb-manager-cli'
  s.require_path = 'lib'
  s.files = Dir.glob("{lib,spec}/**/*")
  s.required_ruby_version = '>= 2.1.2'

  s.add_dependency 'aws-sdk'
  s.add_dependency 'bundler'
  s.add_dependency 'httparty'
  s.add_dependency 'netrc'
  s.add_dependency 'thor'
  s.add_dependency 'rake'
  s.add_dependency 'json'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'fake_dynamo'

end