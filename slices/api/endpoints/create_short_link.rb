# frozen_string_literal: true

module API
  module Endpoints
    class CreateShortLink < Endpoint
      COMPLAINTS = UpdateShortLink::COMPLAINTS
      CONTRACTS = UpdateShortLink::CONTRACTS

      SCHEMA = {
        additionalProperties: false,
        properties: { destination: UpdateShortLink::DESTINATION },
        required: %w[destination],
      }.freeze

      REPLY = Serializers::ShortLink.reference

      include Deps[shorten_link: "shares.operations.shorten_link"]

      def handle(destination:)
        case shorten_link.call(Blog::Types::TrimmedText[destination])
          in Success(link) then Success(serialized(Serializers::ShortLink, link, settings:))
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in unmatched then unhandled(unmatched, "could not make the short link")
        end
      end
    end
  end
end
