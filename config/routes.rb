Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  post "locale/:locale", to: "locales#update", as: :locale
  root to: redirect("/dashboard")
  get "dashboard", to: "dashboard#show", as: :dashboard

  get "scan/:mode", to: "scans#show", as: :scan, constraints: { mode: /ship|return_good|return_damaged/ }
  post "scan/:mode", to: "scans#create", constraints: { mode: /ship|return_good|return_damaged/ }
  post "scan/undo", to: "scans#undo", as: :undo_scan

  get "variants", to: "stock#index", as: :variants
  resources :stock, only: :index
  get "stock_movements", to: "history#index", as: :stock_movements
  resources :history, only: :index
  resources :labels, only: :index

  namespace :finance do
    get "/", to: "overview#show", as: :overview
    post "expenses/preview", to: "expenses#preview", as: :expense_preview
    post "expenses/save-all", to: "expenses#save_all", as: :expense_save_all
    resources :expenses, only: %i[index create edit update destroy]
    resources :purchase_orders, except: :destroy do
      post :mark_ordered, on: :member
      post :add_cost, on: :member
      post :receive, on: :member
    end
    resources :balance_checks, only: %i[index create show] do
      post :create_adjustment, on: :member
    end
    get "balance-check", to: redirect("/finance/balance_checks")
    resources :reports, only: :index do
      get :export, on: :collection
      post :close_month, on: :collection
    end
    get "settings", to: "settings#show"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

end
