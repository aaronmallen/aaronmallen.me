# frozen_string_literal: true

module API
  module Endpoints
    class UpdateTag < TagEndpoint
      PUBLIC = Blog::Types::TagScope["public"]
      SCOPED = true
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, **PROPERTIES },
        required: %w[id scope],
      }.freeze

      include Deps[
        post_queries: "posts.repos.post_queries",
        save_tag: "tags.operations.save_tag",
        tag_queries: "tags.repos.tag_queries",
      ]

      def handle(id:, scope:, scopes:, name: nil, color: nil, **fields)
        current = tag_queries.find_in(scope, id)
        return missing("tag", id) if current.nil?
        return invalid(id: [format(MAIL_TAG, id, "changing")]) if !mail?(scopes) && tag_queries.mail_only?(scope, id)

        saved(save_tag.call({ name: name || current.name, color:, **fields }, scope:, id:), id)
      end

      private

      def public_in(fields)
        name = tag_queries.find_in(fields[:scope], fields[:id])&.name if fields[:scope] == PUBLIC
        "a blog post with this tag" if name && post_queries.shown?(post_queries.by_tag(name).map(&:id))
      end
    end
  end
end
