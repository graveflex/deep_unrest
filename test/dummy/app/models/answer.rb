class Answer < ApplicationRecord
  belongs_to :question
  belongs_to :survey
  belongs_to :applicant
end
