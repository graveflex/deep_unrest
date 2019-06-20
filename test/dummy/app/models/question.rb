# frozen_string_literal: true

class Question < ApplicationRecord
  belongs_to :survey
  has_many :answers, index_errors: true, dependent: :destroy
  has_many :attachments, through: :answers, index_errors: true
  accepts_nested_attributes_for :answers,
                                allow_destroy: true
  accepts_nested_attributes_for :attachments,
                                allow_destroy: true
end
