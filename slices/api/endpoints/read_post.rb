# frozen_string_literal: true

module API
  module Endpoints
    class ReadPost < Endpoint
      KIND = Blog::Types::RecordKind["post"]
      SCHEMA = Helpers::Schema.by_id

      EDIT_NOTES = "the notes left on each change to the published post, newest first"
      RECEIVED = "the webmentions the post has received"
      SUGGESTION = "the suggestion that holds the open edits, to accept or reject them; null when none is open"
      SUGGESTIONS = "the suggested edits still waiting on the author, in the order they apply"

      REPLY = Helpers::Schema.widen(
        Serializers::PostDetail::SCHEMA,
        webmentions_received: { type: "integer", description: RECEIVED },
        edit_notes: Helpers::Schema.list(Serializers::PostEdit.reference).merge(description: EDIT_NOTES),
        suggestion_id: Helpers::Schema.nullable(Helpers::Schema::ID).merge(description: SUGGESTION),
        suggestion_edits: Helpers::Schema.list(Serializers::SuggestionEdit.reference).merge(description: SUGGESTIONS),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        post_queries: "posts.repos.post_queries",
        record_link_queries: "links.repos.record_link_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def handle(id:)
        post = post_queries.by_id(id)
        return not_found(Helpers::Wording.missing("blog post", id)) if post.nil?

        Success(answered(post))
      end

      private

      def answered(post)
        serialized(Serializers::PostDetail, post).merge(
          webmentions_received: webmention_queries.received_count(post.id),
          edit_notes: serialized(Serializers::PostEdit, post_queries.edits_newest_first(post.id)),
          **suggested(suggestion_queries.for_post(post.id)),
          record_links: linked(KIND, post.id),
        )
      end
    end
  end
end
