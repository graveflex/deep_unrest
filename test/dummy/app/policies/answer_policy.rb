class AnswerPolicy < ApplicationPolicy
  def update?
    record.applicant == user
  end

  def destroy?
    update?
  end

  def create?
    user.class == Applicant
  end
end
