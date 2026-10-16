# frozen_string_literal: true

module API
  module Endpoints
    class ListTrustedAuthors < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object(
        { trusted_authors: Helpers::Schema.list(Serializers::TrustedAuthor.reference) },
      ).freeze

      include Deps[webmention_queries: "social.repos.webmention_queries"]

      def handle = Success(trusted_authors: serialized(Serializers::TrustedAuthor, webmention_queries.trusted))
    end
  end
end
