class Answer < ApplicationRecord
  belongs_to :question
  belongs_to :survey
  belongs_to :applicant
  has_many :attachments

  validates :value, format: { with: /\A(?!XXXXX)/ }
end
