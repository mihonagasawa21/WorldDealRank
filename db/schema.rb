# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_03_16_062937) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bookmarks", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_bookmarks_on_post_id"
    t.index ["user_id", "post_id"], name: "index_bookmarks_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "user_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "name_ja"
    t.string "name_en"
    t.string "mofa_country_code"
    t.string "iso2"
    t.string "iso3"
    t.string "currency_code"
    t.integer "safety_level"
    t.datetime "safety_updated_at"
    t.decimal "fx_rate_usd"
    t.date "fx_date"
    t.decimal "ppp_lcu_per_intl"
    t.integer "ppp_year"
    t.decimal "plr"
    t.decimal "final_index"
    t.decimal "deviation_pct"
    t.datetime "calculated_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "jp_resident_count"
    t.integer "jp_resident_year"
    t.integer "jp_resident_month"
    t.integer "jp_resident_day"
    t.string "jp_resident_source_url"
    t.integer "safety_max_level"
    t.string "photo_url"
    t.integer "safety_risk_level", default: 0, null: false
    t.integer "safety_infection_level", default: 0, null: false
    t.datetime "safety_source_updated_at"
    t.datetime "safety_fetched_at"
    t.integer "kind", default: 0, null: false
    t.integer "parent_country_id"
    t.integer "area_type", default: 0, null: false
    t.integer "safety_min_level"
    t.string "mofa_code"
    t.index ["area_type"], name: "index_countries_on_area_type"
    t.index ["iso2"], name: "index_countries_on_iso2"
    t.index ["iso3"], name: "index_countries_on_iso3"
    t.index ["jp_resident_count"], name: "index_countries_on_jp_resident_count"
    t.index ["kind"], name: "index_countries_on_kind"
    t.index ["mofa_code"], name: "index_countries_on_mofa_code", unique: true
    t.index ["mofa_country_code"], name: "index_countries_on_mofa_country_code"
    t.index ["parent_country_id"], name: "index_countries_on_parent_country_id"
    t.index ["safety_max_level"], name: "index_countries_on_safety_max_level"
  end

  create_table "evaluation_settings", force: :cascade do |t|
    t.integer "top_n"
    t.boolean "include_level2"
    t.decimal "weight_cost"
    t.decimal "bonus_level1"
    t.decimal "penalty_level2"
    t.integer "stale_fx_days"
    t.decimal "stale_fx_penalty"
    t.integer "stale_calc_hours"
    t.decimal "stale_calc_penalty"
    t.decimal "grade_a_min"
    t.decimal "grade_b_min"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "likes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_likes_on_post_id"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "body"
    t.integer "overall"
    t.integer "level"
    t.integer "user_id", null: false
    t.string "title", default: "無題", null: false
    t.integer "country_id"
    t.index ["country_id"], name: "index_posts_on_country_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_taggings_on_post_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "password_digest"
    t.boolean "verified", default: false, null: false
    t.string "username"
    t.text "bio"
    t.string "website"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookmarks", "posts"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "likes", "posts"
  add_foreign_key "likes", "users"
  add_foreign_key "posts", "countries"
  add_foreign_key "posts", "users"
  add_foreign_key "taggings", "posts"
  add_foreign_key "taggings", "tags"
end
