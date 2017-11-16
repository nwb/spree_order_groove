Spree::Core::Engine.add_routes do
  namespace :api do
    namespace :v1 do
      post "/ogcreateorder", to: "orders#ogcreateorder", as: "ogcreateorder"
    end
  end
end