# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn < Operation
      USER_AGENT = "HTTP_USER_AGENT"
      USER_AGENT_LIMIT = 1024

      include Deps[
        find_place: "analytics.operations.find_place",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome)
        address = Blog::VisitorAddress.call(request)
        user_agent = readable(request.get_header(USER_AGENT))
        place = find_place.call(address)

        Success(
          sign_in_mutations.create(
            outcome: outcome.to_s, address:, user_agent:, browser: Device.browser(user_agent),
            os: Device.os(user_agent), city: place.city, country: place.country,
          ),
        )
      end

      private

      def readable(header) = header.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete("\u0000")[0, USER_AGENT_LIMIT]
    end
  end
end
