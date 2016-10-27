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
  s.license     = 'GPL-2.0'

  s.executables << 'dynamic-dynamodb-manager-cli'
  s.require_path = 'lib'
  s.files = Dir.glob('{lib,spec,templates}/**/*')
  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'aws-sdk', '2.6.11'
  s.add_dependency 'bundler', '1.13.5'
  s.add_dependency 'bugsnag', '5.0.1'
  s.add_dependency 'dotenv', '2.1.1'
  s.add_dependency 'httparty', '0.14.0'
  s.add_dependency 'io-console', '0.4.3'
  s.add_dependency 'json', '1.8.1'
  s.add_dependency 'netrc', '0.11.0'
  s.add_dependency 'rake', '11.3.0'
  s.add_dependency 'redis', '3.3.1'
  s.add_dependency 'thor', '0.19.1'
  s.add_development_dependency 'rack-test', '0.6.3'
  s.add_development_dependency 'timecop', '0.8.1'
  s.add_development_dependency 'rspec', '3.5.0'
  s.add_development_dependency 'webmock', '2.1.0'

end
