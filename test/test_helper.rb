# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../test/dummy/config/environment.rb', __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path('../../test/dummy/db/migrate', __FILE__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require 'rails/test_help'

DatabaseCleaner.strategy = :transaction

module ActiveSupport
  class TestCase
    if ActiveSupport::TestCase.respond_to?(:fixture_path=)
      self.fixture_path = File.expand_path('../dummy/test/fixtures', __FILE__)
      self.fixture_path = ActiveSupport::TestCase.fixture_path
      self.file_fixture_path = ActiveSupport::TestCase.fixture_path + '/files'
      fixtures :all
    end

    def setup
      DatabaseCleaner.start
    end

    def after_teardown
      DatabaseCleaner.clean
    end

    # create a confirmed email user
    def create_authed_applicant(user = applicants(:one))
      user.save!
      user
    end

    # create admin user
    def create_authed_admin(admin = admins(:one))
      admin.save!
      admin
    end

    # format request body according to JSONAPI expectations
    def xhr_req(params = {}, headers = {})
      {
        params: params.to_json,
        headers: headers.merge(
          CONTENT_TYPE: 'application/json'
        )
      }
    end

    # format a JSONAPI request by an authenticated user.
    # a new confirmed user is created and used unless one is provided
    def auth_xhr_req(params = {}, user = nil)
      user = create_authed_user unless user
      xhr_req(params, user.create_new_auth_token)
    end

    # format a multipart/form-data request by an authenticated user.
    # a new confirmed user is created and used unless one is provided
    def auth_multipart_req(params, user = nil)
      user = create_authed_user unless user
      multipart_req(params, user.create_new_auth_token)
    end
  end
end
