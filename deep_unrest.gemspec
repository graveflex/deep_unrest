# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'deep_unrest/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'deep_unrest'
  s.version     = DeepUnrest::VERSION
  s.authors     = ['Lynn Hurley']
  s.email       = ['lynn.dylan.hurley@gmail.com']
  s.homepage    = 'https://github.com/graveflex/deep_unrest'
  s.summary     = 'Update multiple or deeply nested JSONAPI resources'
  s.description = 'Update multiple or deeply nested JSONAPI resources'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*',
                'MIT-LICENSE',
                'Rakefile',
                'README.md']

  s.add_dependency 'rails', '~> 5.2.3'
  s.add_dependency 'jsonapi-resources', '~> 0.9.10'

  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'omniauth-github', '1.2.3'
  s.add_development_dependency 'pundit', '1.1.0'
  s.add_development_dependency 'dragonfly', '1.1.2'
  s.add_development_dependency 'database_cleaner', '1.6.0'
  s.add_development_dependency 'faker', '1.7.3'
end
