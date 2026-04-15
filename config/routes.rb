Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  get "/sign_in", to: "sessions#new", as: :sign_in
  post "/sign_in", to: "sessions#create"
  delete "/sign_out", to: "sessions#destroy", as: :sign_out

  get "/sign_up", to: "registrations#new", as: :sign_up
  post "/sign_up", to: "registrations#create"

  get "/account", to: "registrations#edit", as: :edit_account
  patch "/account", to: "registrations#update"
  put "/account", to: "registrations#update"

  get "/notifications", to: "notifications#index", as: :notifications
  patch "/notifications/:id/read", to: "notifications#mark_read", as: :mark_notification_read

  get "/push_subscriptions/public_key", to: "push_subscriptions#public_key", as: :push_subscription_public_key
  post "/push_subscriptions", to: "push_subscriptions#create"
  delete "/push_subscriptions", to: "push_subscriptions#destroy"

  root to: "sessions#new"

  get "/calendar", to: "calendars#show", as: :calendar
  get "/calendar/history", to: "calendars#history", as: :calendar_history
  post "/calendar/refresh", to: "calendars#refresh", as: :refresh_calendar
  get "/calendar/day_details", to: "calendars#day_details", as: :day_details
end
