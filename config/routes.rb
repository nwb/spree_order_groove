

Spree::Core::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      post "/ogcreateorder", to: "orders#ogcreateorder", as: "ogcreateorder"
      resources :subscriptions do
        member do
          patch :pause
          patch :unpause
          get :cancellation
          patch :cancel
        end
      end
    end
  end

  namespace :admin do
    resources :subscription_frequencies
    resources :subscriptions, except: [:new, :destroy, :show] do
      member do
        patch :sendnow
        patch :pause
        patch :unpause
        get :cancellation
        patch :cancel
        patch :uncancel
        get "new_cc", to: "subscriptions#new_cc"
        post "new_cc_update", to: "subscriptions#new_cc_update"
      end

    end
    get "subscriptionsreport", to: "subscriptions#subscriptionsreport"
    get "order_placing", to: "subscriptions#order_placing"
  end

  resources :subscriptions, except: [:new, :destroy, :show] do
    member do
      patch :sendnow
      patch :pause
      patch :unpause
      patch :cancel
      patch :uncancel
      get "new_cc", to: "subscriptions#new_cc"
      post "new_cc_update", to: "subscriptions#new_cc_update"
    end
  end

end
