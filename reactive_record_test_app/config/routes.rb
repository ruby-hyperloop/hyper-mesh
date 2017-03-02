Rails.application.routes.draw do

  root :to => "home#index"
  match 'test', :to => "test#index", via: :get
  mount Hyperloop::Engine => "/rr"

end
