class AttachmentResource < BaseResource
  attributes :title,
             :file_uid,
             :file_name,
             :answer_id,
             :applicant_id

  belongs_to :answer
  belongs_to :applicant
end
