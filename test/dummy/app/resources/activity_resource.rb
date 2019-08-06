class ActivityResource < BaseResource
  attributes :log_message,
             :target_id,
             :target_type,
             :user_id,
             :user_type
end
