if Rails.env.development?
  Rails.application.config.assets.configure do |env|
    env.cache = Sprockets::Cache::NullStore.new
  end
end
