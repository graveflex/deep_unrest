Rails.application.routes.draw do
  mount_devise_token_auth_for 'Admin', at: 'admin'

  mount_devise_token_auth_for 'Applicant', at: 'applicant'
  as :applicant do
    # Define routes for Applicant within this block.
  end
  mount DeepUnrest::Engine => "/deep_unrest"
end
