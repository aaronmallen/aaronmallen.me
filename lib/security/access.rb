# frozen_string_literal: true

module Security
  module Access
    DEVICE = %i[browser os city country].freeze
    USER_AGENT = "HTTP_USER_AGENT"
    USER_AGENT_LIMIT = 1024

    def self.read(request, find_place)
      address = Blog::VisitorAddress.call(request)
      user_agent = readable(request.get_header(USER_AGENT))
      place = find_place.call(address)

      {
        address:, user_agent:, browser: Device.browser(user_agent), os: Device.os(user_agent), city: place.city,
        country: place.country,
      }
    end

    def self.readable(header)
      header.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete("\u0000")[0, USER_AGENT_LIMIT]
    end
    private_class_method :readable
  end
end
