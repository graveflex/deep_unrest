class QuestionResource < BaseResource
  attributes :content,
             :survey_id

  has_many :answers

  def self.updatable_fields(ctx)
    return [] unless ctx[:current_user]
    return [] unless ctx[:current_user].class == Admin
    super
  end
end
