class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :require_login, except: [:index, :show]
  before_action :require_owner, only: [:edit, :update, :destroy]
  before_action :load_countries, only: [:new, :create, :edit, :update]

  def index
    @posts = Post.includes(:user, :tags, :country).order(created_at: :desc)

    if params[:q].present?
      raw = params[:q].to_s

      tags = raw.scan(/#([^\s#]+)/).flatten
      keyword = raw.gsub(/#([^\s#]+)/, "").strip
      keyword = nil if keyword.blank?

      if keyword
        q = "%#{keyword}%"
        @posts = @posts.left_joins(:country).where(
          "posts.title LIKE :q OR posts.body LIKE :q OR posts.city LIKE :q OR countries.name_ja LIKE :q",
          q: q
        )
      end

      if tags.any?
        @posts = @posts.joins(:tags).where(tags: { name: tags }).distinct
      end
    end
  end

  def show
  end

  def new
    @post = current_user.posts.build
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: "現地レポートを投稿しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "現地レポートを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "現地レポートを削除しました", status: :see_other
  end

  def change
    add_index :tags, :name, unique: true
    add_index :taggings, [:post_id, :tag_id], unique: true
  end

  private

  def set_post
    @post = Post.includes(:country, :user).find(params[:id])
  end

  def require_owner
    return if @post.user_id == current_user.id
    redirect_to @post, alert: "権限がありません"
  end

  def load_countries
    @countries = Country.order(:name_ja)
  end

  def post_params
    params.require(:post).permit(:country_id, :title, :body, :tag_names, attachments: [])
  end
end
