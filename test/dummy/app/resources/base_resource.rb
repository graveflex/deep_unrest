class BaseResource < JSONAPI::Resource
  include DeepUnrest::Concerns::ResourceScope
  abstract
end
