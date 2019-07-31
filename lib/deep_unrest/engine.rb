require 'deep_unrest/authorization/base_strategy'
require 'deep_unrest/authorization/none_strategy'
require 'deep_unrest/authorization/pundit_strategy'
require 'deep_unrest/paginators/basic'
require 'deep_unrest/concerns/null_concern'
require 'deep_unrest/concerns/map_temp_ids'

module DeepUnrest
  class Engine < ::Rails::Engine
    isolate_namespace DeepUnrest
  end

  mattr_accessor :authorization_strategy
  mattr_accessor :pagination_strategy
  mattr_accessor :page_size
  mattr_accessor :authentication_concern
  mattr_accessor :get_user
  mattr_accessor :before_read
  mattr_accessor :before_update

  self.authorization_strategy = DeepUnrest::Authorization::PunditStrategy
  self.pagination_strategy = DeepUnrest::Paginators::Basic
  self.page_size = 25
  self.authentication_concern = DeepUnrest::Concerns::NullConcern
  self.get_user = proc { current_user }
  self.before_read = nil
  self.before_update = nil

  def self.configure(&_block)
    yield self
  end
end
