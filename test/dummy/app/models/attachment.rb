class Attachment < ApplicationRecord
  belongs_to :applicant, required: false
  belongs_to :answer, required: false
end
