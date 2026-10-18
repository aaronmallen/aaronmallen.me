# frozen_string_literal: true

module API
  module Endpoints
    class RemoveTrustedAuthor < Endpoint
      FINDS = true
      SCHEMA = {
        additionalProperties: false,
        properties: { author_url: { type: "string", description: "the author URL list_trusted_authors gives" } },
        required: %w[author_url],
      }.freeze
      REPLY = Helpers::Schema.object({ author_url: Helpers::Schema::STRING, removed: Helpers::Schema::BOOLEAN }).freeze

      include Deps[remove_trusted_author: "social.operations.remove_trusted_author"]

      def handle(author_url:)
        case remove_trusted_author.call(author_url)
          in Success(removed) then Success(author_url: removed, removed: true)
          in Failure(:not_found) then missing("trusted author", author_url, by: "URL")
          in unmatched then unhandled(unmatched, "could not remove the trusted author")
        end
      end
    end
  end
end
