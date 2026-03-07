# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_one_attached :avatar

  has_many :posts, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_posts, through: :bookmarks, source: :post
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy

  before_validation :normalize_email
  before_validation :normalize_username

  # usernameルール（よくあるSNS寄り）
  # - 3〜30文字（20にしたいならここを20に）
  # - 使えるのは英数字 / _ / .
  # - 先頭末尾は英数字
  VALID_USERNAME = /\A[a-zA-Z0-9](?:[a-zA-Z0-9._]*[a-zA-Z0-9])\z/

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { maximum: 255 }

  validates :username,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { minimum: 3, maximum: 30 }, # ←20にするなら maximum: 20
            format: { with: VALID_USERNAME, message: "は英数字と「.」「_」が使用できます（先頭末尾は英数字）" }

  validate :username_not_consecutive_dots

  def verified_label
    verified? ? "✅認証" : nil
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def username_not_consecutive_dots
    return if username.blank?
    errors.add(:username, "は . を連続で使えません") if username.include?("..")
  end
end