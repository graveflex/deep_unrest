class Survey < ApplicationRecord
  belongs_to :applicant
  has_many :questions, index_errors: true
  has_many :answers, through: :questions, index_errors: true

  accepts_nested_attributes_for :questions,
                                allow_destroy: true
  accepts_nested_attributes_for :answers,
                                allow_destroy: true

  validates_presence_of :name
end
