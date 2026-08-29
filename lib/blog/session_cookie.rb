# frozen_string_literal: true

module Blog
  module SessionCookie
    KEY = "admin.session"
    LIFETIME = 30 * 24 * 60 * 60
    PATH = "/"

    def self.store
      [
        :cookie,
        {
          expire_after: LIFETIME,
          httponly: true,
          key: KEY,
          path: PATH,
          same_site: :lax,
          secrets: Hanami.app.settings.app_secret,
          secure: Hanami.env?(:production),
          serialize_json: true,
        },
      ]
    end
  end
end
