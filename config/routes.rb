Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "home#index"
  get "dashboard", to: "dashboard#index"
  get "history", to: "history#index"
  get "coming-soon/add-purchase", to: "coming_soon#add_purchase", as: :coming_soon_add_purchase
  get "settings", to: "settings#show"
  resource :sign_up, only: [ :show, :create ]
  resources :store_policies, only: [ :new, :create ]
  resources :purchases, only: [ :new, :create ]
end
