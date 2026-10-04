# frozen_string_literal: true

module API
  module Endpoints
    class ReadPost < Endpoint
      KIND = Blog::Types::RecordKind["post"]
      SCHEMA = { additionalProperties: false, properties: { id: Posts::ID }, required: ["id"] }.freeze

      EDIT_NOTES = "the notes left on each change to the published post, newest first"
      RECEIVED = "the webmentions the post has received"
      SUGGESTIONS = "the suggested edits still waiting on the author, in the order they apply"

      REPLY = Schema.widen(
        Serializers::PostDetail::SCHEMA,
        webmentions_received: { type: "integer", description: RECEIVED },
        edit_notes: Schema.list(Serializers::PostEdit.reference).merge(description: EDIT_NOTES),
        suggestion_edits: Schema.list(Serializers::SuggestionEdit.reference).merge(description: SUGGESTIONS),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        edits_newest_first: "posts.queries.edits_newest_first",
        post_by_id: "posts.queries.by_id",
        received_webmention_count: "social.queries.received_webmention_count",
        record_links: "links.queries.record_links",
        suggestion_for_post: "suggestions.queries.for_post",
      ]

      def handle(id:)
        post = post_by_id.call(id)
        return not_found(Posts.missing(id)) if post.nil?

        Success(answered(post))
      end

      private

      def answered(post)
        serialized(Serializers::PostDetail, post).merge(
          webmentions_received: received_webmention_count.call(post.id),
          edit_notes: serialized(Serializers::PostEdit, edits_newest_first.call(post.id)),
          suggestion_edits: serialized(Serializers::SuggestionEdit, open_edits(post)),
          record_links: linked(KIND, post.id),
        )
      end

      def open_edits(post) = suggestion_for_post.call(post.id)&.open_edits || Blog::Constants::EMPTY_ARRAY
    end
  end
end
