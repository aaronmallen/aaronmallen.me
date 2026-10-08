# frozen_string_literal: true

module Security
  module Operations
    class ReadAccess
      DEVICE = %i[browser os city country country_name].freeze
      USER_AGENT = "HTTP_USER_AGENT"
      USER_AGENT_LIMIT = 1024

      include Deps[
        "operations.read_device",
        "operations.read_visitor_address",
        find_place: "analytics.operations.find_place",
      ]

      def call(request)
        address = read_visitor_address.call(request)
        user_agent = readable(request.get_header(USER_AGENT))
        place = find_place.call(address)

        { address:, user_agent:, **read_device.call(user_agent), **place.to_h }
      end

      private

      def readable(header)
        header.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete("\u0000")[0, USER_AGENT_LIMIT]
      end
    end
  end
end
