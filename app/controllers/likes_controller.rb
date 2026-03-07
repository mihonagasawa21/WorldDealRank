class LikesController < ApplicationController
  before_action :require_login
  before_action :set_post

  def create
    current_user.likes.find_or_create_by!(post_id: @post.id)
    redirect_back fallback_location: posts_path
  end

  def destroy
    current_user.likes.where(post_id: @post.id).destroy_all
    redirect_back fallback_location: posts_path
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end
end