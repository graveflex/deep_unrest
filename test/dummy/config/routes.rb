Rails.application.routes.draw do
  mount_devise_token_auth_for 'Admin', at: 'admin'
  mount_devise_token_auth_for 'Applicant', at: 'applicant'
  mount DeepUnrest::Engine => '/deep_unrest'
  patch 'update', to: 'application#update'

  jsonapi_resources :surveys
end
