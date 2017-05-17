class AnswerResource < BaseResource
  attributes :value,
             :question_id,
             :survey_id,
             :applicant_id

  def self.updatable_fields(ctx)
    return [] unless ctx[:current_user]
    return [] unless ctx[:current_user].class == Applicant
    super
  end
end
