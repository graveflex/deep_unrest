class SurveyPolicy < ApplicationPolicy
  def update?
    user.class == Admin || user == record.applicant
  end

  def create?
    user
  end

  def destroy?
    update?
  end

  def update_all?
    user
  end

  def destroy_all?
    user
  end

  class Scope < Scope
    def resolve
      if user.class == Admin
        scope.all
      elsif user.class == Applicant
        scope.where(applicant: user)
      else
        scope.none
      end
    end
  end
end
