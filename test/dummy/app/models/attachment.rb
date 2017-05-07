class Attachment < ApplicationRecord
  belongs_to :applicant
  belongs_to :answer
end
