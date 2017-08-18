class ApplicationRecord < ActiveRecord::Base
  include DeepUnrest::Concerns::MapTempIds
  self.abstract_class = true
end
