# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :require_login, only: [:mypage, :edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params_create)
    if @user.save
      session[:user_id] = @user.id
      redirect_to mypage_path, notice: "登録してログインしました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def mypage
    @user = current_user
    @my_posts = @user.posts.includes(:country).order(created_at: :desc)
    @bookmarked_posts = @user.bookmarked_posts.includes(:country, :user).order(created_at: :desc)

    render "users/mypage"
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    # パスワード欄が空なら更新対象から外す（変更しない）
    attrs = user_params_update.to_h
    if attrs["password"].blank? && attrs["password_confirmation"].blank?
      attrs.delete("password")
      attrs.delete("password_confirmation")
    end

    if @user.update(attrs)
      redirect_to mypage_path, notice: "マイページ情報を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def mypage_posts
    @user = current_user
    @my_posts = @user.posts.includes(:country).order(created_at: :desc)
  end

  def mypage_saved
    @user = current_user
    @bookmarked_posts = @user.bookmarked_posts.includes(:country, :user).order(created_at: :desc)
  end
  
  private

  def user_params_create
    params.require(:user).permit(:username, :bio, :website, :email, :password, :password_confirmation, :avatar)
  end

  def user_params_update
    params.require(:user).permit(:username, :bio, :website, :email, :password, :password_confirmation, :avatar)
  end
end