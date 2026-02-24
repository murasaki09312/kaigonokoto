Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/auth/login", to: "auth#login"
  get "/auth/me", to: "auth#me"
  post "/auth/logout", to: "auth#logout"
  post "/api/v1/reservations/generate", to: "reservations#generate"
  post "/api/v1/invoices/generate", to: "api/v1/invoices#generate"
  get "/api/v1/today_board", to: "api/v1/today_board#index"
  get "/api/v1/shuttle_board", to: "api/v1/shuttle_board#index"
  get "/api/v1/invoices", to: "api/v1/invoices#index"
  get "/api/v1/invoices/:id", to: "api/v1/invoices#show"
  put "/api/v1/reservations/:reservation_id/attendance", to: "api/v1/attendances#upsert"
  put "/api/v1/reservations/:reservation_id/care_record", to: "api/v1/care_records#upsert"
  put "/api/v1/reservations/:reservation_id/shuttle_legs/:direction", to: "api/v1/shuttle_legs#upsert", constraints: { direction: /pickup|dropoff/ }

  resources :tenants, only: [ :index, :create ]
  resources :users, only: [ :index, :create, :show, :update ]
  resources :clients, only: [ :index, :show, :create, :update, :destroy ] do
    resources :contracts, only: [ :index, :show, :create, :update ]
  end
  resources :reservations, only: [ :index, :show, :create, :update, :destroy ] do
    collection do
      post :generate
    end
  end
end
