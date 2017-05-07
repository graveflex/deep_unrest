class Survey < ApplicationRecord
  belongs_to :applicant
  has_many :questions
  has_many :answers
end
