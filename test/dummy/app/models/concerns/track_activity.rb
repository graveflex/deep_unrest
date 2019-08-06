# frozen_string_literal: true

require 'active_support/concern'

module TrackActivity
  extend ActiveSupport::Concern
  included do
    after_save :track_activity
  end

  def track_activity
    return unless saved_changes?
    Activity.create!(user: user,
                     target: self,
                     log_message: log_message)
  end

  def log_message
    "#{user.class} #{user.id} updated #{self.class} #{id}"
  end

  def user
    attrs = self.class.column_names
    return admin if attrs.include? 'admin_id'
    return applicant if attrs.include? 'applicant_id'
  end
end
