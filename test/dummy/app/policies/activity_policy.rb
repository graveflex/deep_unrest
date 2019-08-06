class ActivityPolicy < ApplicationPolicy
  def update?
    user.class == Admin
  end

  def create?
    update?
  end

  def destroy?
    update?
  end

  def update_all?
    update?
  end

  def destroy_all?
    update?
  end

  class Scope < Scope
    def resolve
      if user.class == Admin
        scope.all
      else
        scope.none
      end
    end
  end
end
