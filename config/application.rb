require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module RateMatch
  class Application < Rails::Application
    config.load_defaults 7.2

    config.time_zone = "Tokyo"
    config.autoload_lib(ignore: %w[assets tasks])
    config.i18n.default_locale = :ja
  end
end