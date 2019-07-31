class ApplicantPolicy < ApplicationPolicy
  def update?
    record == user
  end

  def destroy?
    update?
  end
end
