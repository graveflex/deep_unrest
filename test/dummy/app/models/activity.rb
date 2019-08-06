class Activity < ApplicationRecord
  belongs_to :user, polymorphic: true
  belongs_to :target, polymorphic: true
end
