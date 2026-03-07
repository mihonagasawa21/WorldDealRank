class Post < ApplicationRecord
  belongs_to :user
  belongs_to :country, optional: true

  has_many_attached :attachments

  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_users, through: :bookmarks, source: :user

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy 
  
  validates :title, presence: true, length: { maximum: 120 }
  validates :body, presence: true
  validates :country_id, presence: true, on: :create

  attr_accessor :tag_names

  after_save :sync_tags_from_input

  def bookmarked_by?(user)
    return false if user.nil?
    bookmarks.any? { |b| b.user_id == user.id }
  end

  private

  def sync_tags_from_input
    return if tag_names.nil?

    names =
      tag_names.to_s
               .gsub("＃", "#")
               .split(/[[:space:]]+/)
               .map { |s| s.delete_prefix("#").strip }
               .reject(&:blank?)
               .uniq

    self.tags = names.map { |n| Tag.find_or_create_by!(name: n) }
  end
end