# frozen_string_literal: true

source 'https://rubygems.org'

# Declare your gem's dependencies in deep_unrest.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

group :development, :test do
  gem 'devise_token_auth', github: 'lynndylanhurley/devise_token_auth'
  gem 'jsonapi-resources', '~> 0.10'
  gem 'pry-rails'
  gem 'rubocop', '0.48.1', require: false
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'database_cleaner', '1.6.0'
  gem 'dragonfly', '1.3.0'
  gem 'faker', '2.18.0'
  gem 'mocha', '1.3.0'
  gem 'omniauth-github', '2.0.0'
  gem 'pundit', '2.1.0'
  gem 'sqlite3'
end
