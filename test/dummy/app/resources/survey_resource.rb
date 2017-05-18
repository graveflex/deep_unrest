class SurveyResource < BaseResource
  attributes :name,
             :approved,
             :applicant_id
  has_many :questions
  has_one :applicant

  def self.updatable_fields(ctx)
    return [] unless ctx[:current_user]
    if ctx[:current_user].class == Admin
      super - [:name]
    elsif ctx[:current_user].class == Applicant
      super - [:approved]
    end
  end
end
