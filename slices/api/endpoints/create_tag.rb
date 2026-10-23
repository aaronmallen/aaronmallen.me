# frozen_string_literal: true

module API
  module Endpoints
    class CreateTag < TagEndpoint
      FINDS = true
      SCHEMA = { additionalProperties: false, properties: PROPERTIES, required: ["scope"] }.freeze

      include Deps[save_tag: "tags.operations.save_tag"]

      def handle(scope:, name: nil, color: nil, project: nil, **fields)
        project_id_for(scope, project).bind do |project_id|
          saved(save_tag.call({ name:, color:, **fields }, scope:, project_id:))
        end
      end
    end
  end
end
