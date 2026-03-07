class BookmarksController < ApplicationController
  before_action :require_login
  before_action :set_post

  def create
    current_user.bookmarks.find_or_create_by!(post: @post)
    redirect_back fallback_location: posts_path
  end

  def destroy
    current_user.bookmarks.where(post: @post).destroy_all
    redirect_back fallback_location: posts_path
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end
end