Rails.application.routes.draw do
  root to: "receipts#new"
  get "receipts/new" => "receipts#new", as: :new_receipt

  resources :receipts, only: %i[create edit update index show destroy] do
    member do
      get :processing
      get :status
      post :reprocess
    end
    collection do
      get :pending
    end
  end
end

Rails.application.routes.append do
  match "*unmatched", to: redirect("/"), via: :all
end
