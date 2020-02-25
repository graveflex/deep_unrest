DeepUnrest::Engine.routes.draw do
  patch 'update', to: 'application#update'
  get 'read', to: 'application#read'
  patch 'read', to: 'application#read'
  patch 'write', to: 'application#write'
end
