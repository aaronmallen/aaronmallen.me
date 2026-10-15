# frozen_string_literal: true

module API
  module Endpoints
    class UpdateTag < TagEndpoint
      SCOPED = true
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, **PROPERTIES },
        required: %w[id scope],
      }.freeze

      include Deps[save_tag: "tags.operations.save_tag", tag_queries: "tags.repos.tag_queries"]

      def handle(id:, scope:, scopes:, name: nil, color: nil)
        current = tag_queries.find_in(scope, id)
        return missing("tag", id) if current.nil?
        return invalid(id: [format(MAIL_TAG, id, "changing")]) if !mail?(scopes) && tag_queries.mail_only?(scope, id)

        saved(save_tag.call({ name: name || current.name, color: }, scope:, id:), id)
      end
    end
  end
end
