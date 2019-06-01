class Attachment < ApplicationRecord
  include TrackActivity
  belongs_to :applicant, required: false
  belongs_to :answer, required: false
end
