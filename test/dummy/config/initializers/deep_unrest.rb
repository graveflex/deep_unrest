DeepUnrest.configure do |config|
  config.authentication_concern = DeviseTokenAuth::Concerns::SetUserByToken
  config.get_user = proc { current_admin || current_applicant }
end
