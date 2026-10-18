# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkWebmentionEndpoint < BulkEndpoint
      KEY = :webmentions
      NOUN = "webmention"
      REPLY = Helpers::Schema.object({ webmentions: Helpers::Schema.list(Serializers::Webmention.reference) }).freeze
      SCHEMA = Webmentions::BULK
      SCOPED = true
      SPAM = Blog::Types::WebmentionVerdict["spam"]

      include Deps[
        act_on: "social.operations.act_on_webmentions",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def handle(ids:, scopes:)
        return Failure(Structs::Refusal.undeleted("a trusted author")) if distrusts?(ids, scopes)

        super(ids:)
      end

      private

      def answered(mentions) = serialized(Serializers::Webmention, mentions)

      def distrusts?(ids, scopes)
        self.class::ACT == SPAM && !scopes.include?(OperationTable::DELETE) &&
          webmention_queries.trusted_author_among?(ids)
      end
    end
  end
end
