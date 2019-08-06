# frozen_string_literal: true

class Survey < ApplicationRecord
  include TrackActivity
  belongs_to :applicant
  has_many :questions,
           index_errors: true,
           dependent: :destroy
  has_many :answers,
           index_errors: true,
           dependent: :destroy
  has_many :attachments,
           through: :answers,
           index_errors: true

  accepts_nested_attributes_for :questions,
                                allow_destroy: true
  accepts_nested_attributes_for :answers,
                                allow_destroy: true
  accepts_nested_attributes_for :attachments,
                                allow_destroy: true

  validates_presence_of :name
end
