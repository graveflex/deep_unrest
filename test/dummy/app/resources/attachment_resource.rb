class AttachmentResource < BaseResource
  attributes :title
  belongs_to :answer
end
