Spree::Core::Engine.add_routes do
  namespace :api do
    #resources :orders do
    #  collection do
    #    post 'ogcreateorder'
    #  end
    #end
    post "/orders/ogcreateorder", to: "orders#ogcreateorder", as: "ogcreateorder"
  end
end