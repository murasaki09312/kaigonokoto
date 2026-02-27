Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/auth/login", to: "auth#login"
  get "/auth/me", to: "auth#me"
  post "/auth/logout", to: "auth#logout"
  post "/api/webhooks/line", to: "api/webhooks/line#create"
  post "/api/v1/reservations/generate", to: "reservations#generate"
  post "/api/v1/invoices/generate", to: "api/v1/invoices#generate"
  get "/api/v1/today_board", to: "api/v1/today_board#index"
  get "/api/v1/shuttle_board", to: "api/v1/shuttle_board#index"
  get "/api/v1/invoices", to: "api/v1/invoices#index"
  get "/api/v1/invoices/:id", to: "api/v1/invoices#show"
  get "/api/v1/admin/users", to: "api/v1/admin/users#index"
  put "/api/v1/admin/users/:id/roles", to: "api/v1/admin/users#update_roles"
  patch "/api/v1/admin/users/:id/roles", to: "api/v1/admin/users#update_roles"
  put "/api/v1/reservations/:reservation_id/attendance", to: "api/v1/attendances#upsert"
  put "/api/v1/reservations/:reservation_id/care_record", to: "api/v1/care_records#upsert"
  put "/api/v1/reservations/:reservation_id/shuttle_legs/:direction", to: "api/v1/shuttle_legs#upsert", constraints: { direction: /pickup|dropoff/ }

  resources :tenants, only: [ :index, :create ]
  resources :users, only: [ :index, :create, :show, :update ]
  resources :clients, only: [ :index, :show, :create, :update, :destroy ] do
    resources :contracts, only: [ :index, :show, :create, :update ]
    resources :family_members, only: [ :index ] do
      post :line_invitation, on: :member
    end
  end
  resources :reservations, only: [ :index, :show, :create, :update, :destroy ] do
    collection do
      post :generate
    end
  end
end
