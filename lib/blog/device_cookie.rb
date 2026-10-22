# frozen_string_literal: true

module Blog
  module DeviceCookie
    KEY = "admin.device"
    LIFETIME = 400 * 24 * 60 * 60

    def self.cookie(id)
      { value: id, httponly: true, expires: Time.now + LIFETIME, path: "/admin", same_site: :lax,
        secure: Hanami.env?(:production) }
    end
  end
end
