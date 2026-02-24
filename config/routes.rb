Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/auth/login", to: "auth#login"
  get "/auth/me", to: "auth#me"
  post "/auth/logout", to: "auth#logout"
  post "/api/v1/reservations/generate", to: "reservations#generate"

  resources :tenants, only: [:index, :create]
  resources :users, only: [:index, :create, :show, :update]
  resources :clients, only: [:index, :show, :create, :update, :destroy] do
    resources :contracts, only: [:index, :show, :create, :update]
  end
  resources :reservations, only: [:index, :show, :create, :update, :destroy] do
    collection do
      post :generate
    end
  end
end
