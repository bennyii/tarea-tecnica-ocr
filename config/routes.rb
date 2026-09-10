Rails.application.routes.draw do
  resources :posts
   root to: "receipts#new"
   get "receipts/new" => "receipts#new", as: :new_receipt


  resources :receipts, only: %i[create edit update index show destroy] do
    member do
      get :processing
      get :status
      post :reprocess
    end
  end
end