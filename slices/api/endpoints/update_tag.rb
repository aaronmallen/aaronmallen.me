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

      def handle(id:, scope:, scopes:, project: nil, **fields)
        owner = project ? project_id_for(scope, project) : Success(nil)
        owner.bind { changed(id, scope, scopes, it, **fields) }
      end

      private

      def changed(id, scope, scopes, project_id, name: nil, color: nil, **fields)
        current = tag_queries.find_in(scope, id, project_id:)
        return missing("tag", id) if current.nil?

        return invalid(id: [format(MAIL_TAG, id, "changing")]) if !mail?(scopes) && tag_queries.mail_only?(scope, id)

        saved(save_tag.call({ name: name || current.name, color:, **fields }, scope:, id:, project_id:), id)
      end

      def going_public(fields)
        name = tag_queries.find_in(fields[:scope], fields[:id])&.name if fields[:scope] == PUBLIC
        return if name.nil?
        return "a blog post with this tag" if post_queries.shown?(post_queries.by_tag(name).map(&:id))

        "a public project with this tag" if project_queries.public_by_tag(name).any?
      end
    end
  end
end
