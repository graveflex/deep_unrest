# frozen_string_literal: true

class AttachmentPolicy < ApplicationPolicy
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
