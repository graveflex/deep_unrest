class Question < ApplicationRecord
  belongs_to :survey
  has_many :answers, index_errors: true
  accepts_nested_attributes_for :answers,
                                allow_destroy: true
end
