class CommentsController < ApplicationController
  before_action :require_login
  before_action :set_post

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = current_user
    @comment.save!
    redirect_back fallback_location: post_path(@post)
  end

  def destroy
    comment = @post.comments.find(params[:id])
    comment.destroy if comment.user_id == current_user.id
    redirect_back fallback_location: post_path(@post)
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end