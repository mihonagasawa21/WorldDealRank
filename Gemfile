source "https://rubygems.org"

ruby "3.2.7"

gem "rails", "~> 7.2.3"
gem "bootsnap", require: false

# gem "sqlite3", "~> 2.9"
gem "puma", "~> 7.2"

gem "devise"

gem "sprockets-rails"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "image_processing", "~> 1.12"

gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

gem "faraday", "~> 2.9"
gem "faraday-retry", "~> 2.2"
gem "nokogiri", "~> 1.16"
gem "roo", "~> 3.0"
gem "countries"
gem "whenever", require: false

gem "bcrypt", "~> 3.1"
gem "sassc-rails"

group :development, :test do
  gem "debug", platforms: %i[ mingw mswin x64_mingw ]
  gem 'sqlite3' # 追加
  gem 'dotenv-rails' # 追加
end

# PostgreSQL → 本番用
group :production do
  gem 'pg'
end




