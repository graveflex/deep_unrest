# frozen_string_literal: true

class SurveyResource < BaseResource
  attributes :name,
             :approved,
             :applicant_id
  has_many :questions
  has_one :applicant

  before_update :authorize_active_applicant
  before_save :track_save
  before_update :track_update
  before_create :track_create
  before_remove :track_remove

  # used to test that resource has access to current_user context
  def authorize_active_applicant
    user = context[:current_user]
    return unless user.is_a?(Applicant) && !user.active
    raise Pundit::NotAuthorizedError,
          'applicants cannot modify inactive surveys'
  end

  def track_save; end

  def track_update; end

  def track_create; end

  def track_remove; end

  def self.updatable_fields(ctx)
    return [] unless ctx[:current_user]
    if ctx[:current_user].class == Admin
      super - [:name]
    elsif ctx[:current_user].class == Applicant
      super - [:approved]
    end
  end

  def self.creatable_fields(ctx)
    updatable_fields(ctx)
  end
end
