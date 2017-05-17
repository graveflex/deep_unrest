require 'deep_unrest/authorization/base_strategy'
require 'deep_unrest/authorization/none_strategy'
require 'deep_unrest/authorization/pundit_strategy'
require 'deep_unrest/concerns/null_concern'

module DeepUnrest
  class Engine < ::Rails::Engine
    isolate_namespace DeepUnrest
  end

  mattr_accessor :authorization_strategy
  mattr_accessor :authentication_concern
  mattr_accessor :get_user

  self.authorization_strategy = DeepUnrest::Authorization::PunditStrategy
  self.authentication_concern = DeepUnrest::Concerns::NullConcern
  self.get_user = proc { current_user }

  def self.configure(&_block)
    yield self
  end
end
