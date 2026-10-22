# frozen_string_literal: true

module API
  module Endpoints
    class UpdateShortLink < Endpoint
      COMPLAINTS = {
        code: {
          Blog::Contract::FORMAT => "code takes lowercase letters and digits, with single hyphens between them",
          ::Shares::Helpers::Code::TAKEN => "another share or short link already has this code",
        },
        destination: { Blog::Contract::FORMAT => "destination is a web address that starts with http:// or https://" },
      }.freeze
      CONTRACTS = [::Shares::Contracts::ShortLinkContract].freeze
      DESTINATION = { type: "string", description: "the web address the short link sends a reader to" }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          destination: DESTINATION,
          code: { type: "string", description: "the link's new short code; the old link stops working" },
          title: { type: "string", description: "the link's title; empty to have the site read it from the page" },
        },
        required: %w[id],
      }.freeze

      REPLY = Serializers::ShortLink.reference

      include Deps[
        save_short_link: "shares.operations.save_short_link", short_link_queries: "shares.repos.short_link_queries",
      ]

      def handle(id:, **fields)
        link = short_link_queries.find(id)
        return missing("short link", id) unless link

        case save_short_link.call(id, { destination: link.destination, code: link.code, title: link.title, **fields })
          in Success(_) then Success(serialized(Serializers::ShortLink, short_link_queries.find(id), settings:))
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
