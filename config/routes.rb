Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "home#index"
  resource :sign_up, only: [ :show, :create ]
end
