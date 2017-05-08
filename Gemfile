# frozen_string_literal: true

source 'https://rubygems.org'

gem 'deep_merge', '1.1.1', require: 'deep_merge/rails_compat'

# Declare your gem's dependencies in deep_unrest.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

group :development, :test do
  gem 'pry-rails'
  gem 'rubocop', '0.48.1', require: false
end

group :test do
  gem 'database_cleaner', '1.6.0'
  gem 'devise_token_auth', '0.1.40'
  gem 'dragonfly', '1.1.2'
  gem 'faker', '1.7.3'
  gem 'omniauth-github', '1.2.3'
  gem 'pundit', '1.1.0'
  gem 'sqlite3'
end
