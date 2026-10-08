# frozen_string_literal: true

module API
  module Actions
    module Tokens
      class Show < Action
        SCHEMA = { additionalProperties: false }.freeze
        REPLY = Helpers::Schema.object(
          { name: Helpers::Schema::STRING, created_at: Helpers::Schema::STAMP, last_used_at: Helpers::Schema::STAMP },
        ).freeze

        def handle(_request, response) = render_json(response, described(response[:token]))

        private

        def described(token)
          {
            name: token.name,
            created_at: token.created_at.utc.iso8601,
            last_used_at: token.last_used_at.utc.iso8601,
          }
        end
      end
    end
  end
end
