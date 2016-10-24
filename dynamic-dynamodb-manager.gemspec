require 'date'

Gem::Specification.new do |s|
  s.name        = 'dynamic-dynamodb-manager'
  s.version     = '0.0.1'
  s.date        = Date.today.to_s
  s.summary     = 'Manages DynamoDB tables and streams'
  s.description = ''
  s.authors     = ['Jonathan Hosmer']
  s.email       = 'jonathan@wink.com'
  s.files       = ['lib/dynamic_dynamodb_manager.rb']
  s.homepage    = 'https://github.com/winkapp/dynamic-dynamodb-manager'
  s.license     = 'GPLv2'

  s.executables << 'dynamic-dynamodb-manager-cli'
  s.require_path = 'lib'
  s.files = Dir.glob('{lib,spec,templates}/**/*')
  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'aws-sdk'
  s.add_dependency 'bundler'
  s.add_dependency 'httparty'
  s.add_dependency 'netrc'
  s.add_dependency 'thor'
  s.add_dependency 'rake'
  s.add_dependency 'json'
  s.add_dependency 'dotenv'
  s.add_dependency 'bugsnag'
  s.add_dependency 'io-console'
  s.add_dependency 'redis'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'webmock'

end
