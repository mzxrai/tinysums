require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API routes
  namespace :api do
    resources :stories, only: [ :index, :show ]
  end

  # Mount Sidekiq web UI
  mount Sidekiq::Web => "/sidekiq"

  # Set root path to React SPA
  root "react#index"

  # Catch-all route for React SPA - MUST be the last route
  get "*path", to: "react#index", constraints: lambda { |request|
    # Only handle HTML requests (exclude API, assets, and non-HTML requests)
    request.format.html? &&
    # Use a single regex match instead of multiple string comparisons
    !request.path.match?(/\A\/(api|assets|cable|sidekiq)\//)
  }
end