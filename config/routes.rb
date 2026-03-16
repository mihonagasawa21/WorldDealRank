# config/routes.rb
Rails.application.routes.draw do
  # Pages
  get "ranking" => "pages#ranking", as: :ranking
  get "world"   => "pages#world",   as: :world
  get "fx"      => "pages#fx",      as: :fx


  get "mypage" => "users#mypage", as: :mypage
  resources :users, only: [:new, :create, :edit, :update]
  resource :session, only: [:new, :create, :destroy]
  get "mypage/posts" => "users#mypage_posts", as: :mypage_posts
  get "mypage/saved" => "users#mypage_saved", as: :mypage_saved
  
  # Posts / Likes / Comments / Tags
 resources :posts do
  resource :like, only: [:create, :destroy]
  resource :bookmark, only: [:create, :destroy]
  resources :comments, only: [:create, :destroy]
end

resources :tags, only: [:show]

  # Admin
  get   "admin/setting/edit" => "admin/settings#edit",   as: :edit_admin_setting
  patch "admin/setting"      => "admin/settings#update", as: :admin_setting

  get   "admin/countries"          => "admin/countries#index",  as: :admin_countries
  get   "admin/countries/:id/edit" => "admin/countries#edit",   as: :edit_admin_country
  patch "admin/countries/:id"      => "admin/countries#update", as: :admin_country

  get   "admin/cost_index"         => "admin/cost_index#index",   as: :admin_cost_index
  post  "admin/cost_index/refresh" => "admin/cost_index#refresh", as: :refresh_admin_cost_index

  root "pages#ranking"
end