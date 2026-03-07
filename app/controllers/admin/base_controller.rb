module Admin
  class BaseController < ApplicationController
    before_action :http_basic_auth

    private

    def http_basic_auth
      user = ENV.fetch("ADMIN_USER", "admin")
      pass = ENV.fetch("ADMIN_PASSWORD", "password")

      authenticate_or_request_with_http_basic do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) &&
          ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
      end
    end
  end
end
