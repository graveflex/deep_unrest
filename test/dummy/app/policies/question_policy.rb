class QuestionPolicy < ApplicationPolicy
  def update?
    user.is_a? Admin
  end
end
