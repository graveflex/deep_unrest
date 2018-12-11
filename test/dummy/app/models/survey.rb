# frozen_string_literal: true

class Survey < ApplicationRecord
  belongs_to :applicant
  has_many :questions,
           index_errors: true,
           dependent: :destroy
  has_many :answers,
           through: :questions,
           index_errors: true,
           inverse_of: :survey
  has_many :attachments, through: :answers, index_errors: true

  accepts_nested_attributes_for :questions,
                                allow_destroy: true
  accepts_nested_attributes_for :answers,
                                allow_destroy: true
  accepts_nested_attributes_for :attachments,
                                allow_destroy: true

  validates_presence_of :name
end
