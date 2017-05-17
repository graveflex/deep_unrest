require 'deep_unrest/authorization/base_strategy'
require 'deep_unrest/authorization/none_strategy'
require 'deep_unrest/authorization/pundit_strategy'

module DeepUnrest
  class Engine < ::Rails::Engine
    isolate_namespace DeepUnrest
  end

  mattr_accessor :authorization_strategy

  self.authorization_strategy = DeepUnrest::Authorization::PunditStrategy
end
