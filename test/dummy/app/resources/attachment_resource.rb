class AttachmentResource < BaseResource
  attributes :title,
             :file_uid,
             :file_name,
             :applicant_id

  belongs_to :answer
  belongs_to :applicant
end
