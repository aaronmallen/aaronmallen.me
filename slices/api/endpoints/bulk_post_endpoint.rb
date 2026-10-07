# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkPostEndpoint < Endpoint
      NOT_DRAFT = "blog post %s is not a draft"
      REPLY = Schema.object({ posts: Schema.list(Serializers::Post.reference) }).freeze
      UNCHANGED = "could not change blog post %s"

      include Deps[act_on_posts: "posts.operations.act_on_posts"]

      private

      def acted(ids, **input)
        case act_on_posts.call({ act: self.class::ACT, ids:, **input })
          in Success[*posts] then Success(posts: answered(posts))
          in Failure[:record, id, reason] then refused(id, reason)
          in Failure[:invalid, errors] then rejected(flat(errors), Posts::COMPLAINTS)
          else failed(Wording::UNSAVED)
        end
      end

      def answered(posts) = serialized(Serializers::Post, posts)

      def refused(id, reason)
        case reason
          when :not_found then invalid(ids: [Wording.missing("blog post", id)])
          when :not_draft then invalid(ids: [format(NOT_DRAFT, id)])
          else failed(format(UNCHANGED, id))
        end
      end
    end
  end
end
