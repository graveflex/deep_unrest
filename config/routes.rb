DeepUnrest::Engine.routes.draw do
  patch 'update', to: 'application#update'
  get 'read', to: 'application#read'
end
