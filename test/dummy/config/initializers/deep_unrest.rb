DeepUnrest.configure do |config|
  config.authentication_concern = DeviseTokenAuth::Concerns::SetUserByToken
  config.get_user = proc { current_admin || current_applicant }

  prevent_access = proc do
    raise Pundit::NotAuthorizedError if current_user&.name == 'homer'
    raise Pundit::NotAuthorizedError if params.dig(:data, :context, :block_me)
  end

  config.before_read = prevent_access
  config.before_update = prevent_access
end
