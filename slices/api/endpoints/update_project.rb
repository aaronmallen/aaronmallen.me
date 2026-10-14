# frozen_string_literal: true

module API
  module Endpoints
    class UpdateProject < ProjectEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, **PROPERTIES },
        required: ["id"],
      }.freeze

      def handle(id:, **fields)
        current = project_queries.by_id(id)
        current ? saved(fields, current:) : missing(id)
      end
    end
  end
end
